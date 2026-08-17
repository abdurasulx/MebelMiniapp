import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'google_auth_config.dart';
import 'models.dart';

/// Foydalanuvchi profilida tanlaydigan ko'rinish rejimi — bitta hisob ham
/// xaridor, ham (agar biror firmada ishlasa) usta sifatida ilovadan
/// foydalana oladi. Faqat mahalliy UI holati, backend `role`ga bog'liq emas
/// (iOS'dagi `AppMode` bilan bir xil naqsh).
enum AppMode { customer, worker }

class OTPRequestResult {
  final String? debugCode;
  final int resendAfter;
  OTPRequestResult({this.debugCode, required this.resendAfter});
}

class AuthStore extends ChangeNotifier {
  AppUser? user;
  bool isAuthenticated = false;
  bool isNewUser = false;
  String? errorMessage;
  AppMode appMode = AppMode.customer;
  // Multi-role xodim qaysi kasb bilan ishlayotgani (web'dagi "active_position"
  // bilan bir xil naqsh) — bitta kasbi bo'lsa avtomatik shu qiymat, bir
  // nechtasi bo'lsa Profil ekranidagi RolePicker orqali tanlanadi.
  String? activePosition;

  static const _tokensKey = 'fp.tokens';
  static const _appModeKey = 'fp.appMode';
  static const _activePositionKey = 'fp.activePosition';

  // Tokenlar saqlangan, lekin `/users/me/` hali muvaffaqiyatli yuklanmagan
  // (masalan ilova oflaynda ochilgan). Shu holatda ulanish tiklanganda
  // qayta urinish kerak — aks holda `user`/`isAuthenticated` doim `null`/
  // `false` bo'lib qolib, Profil "kirilmagan" ko'rinishida, Sevimlilar esa
  // hech qachon yuklanmay qolar edi.
  bool _hasStoredTokens = false;

  // Google/Telegram orqali yaratilgan yangi hisob backendda
  // `registration_completed=False` bilan boshlanadi — profil to'ldirish
  // qadami shu holatda `/complete-registration/`ga (rol bilan) yuborishi
  // kerak, OTP orqali yaratilganda esa (registration_completed allaqachon
  // `True`) oddiy `/users/me/` PATCH bilan — qarang completeProfile().
  bool _needsRoleCompletion = false;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_appModeKey);
    if (savedMode == 'worker') appMode = AppMode.worker;
    activePosition = prefs.getString(_activePositionKey);

    final raw = prefs.getString(_tokensKey);
    if (raw != null) {
      final tokens = TokenPair.fromJson(jsonDecode(raw));
      ApiClient.instance.setTokens(tokens);
      ApiClient.instance.onTokensRotated = _persist;
      _hasStoredTokens = true;
      await _loadMe();
    }
    ApiClient.instance.isOffline.addListener(_onConnectivityChanged);
    notifyListeners();
  }

  void _onConnectivityChanged() {
    if (!ApiClient.instance.isOffline.value &&
        _hasStoredTokens &&
        user == null) {
      _loadMe();
    }
  }

  void setAppMode(AppMode mode) {
    appMode = mode;
    SharedPreferences.getInstance().then(
      (p) => p.setString(_appModeKey, mode.name),
    );
    notifyListeners();
  }

  /// Xodim rejimiga o'tish — bitta kasbi bo'lsa shu avtomatik, bir nechtasi
  /// bo'lsa RolePicker orqali tanlangan `position` beriladi.
  void enterWorkerMode(String position) {
    appMode = AppMode.worker;
    activePosition = position;
    SharedPreferences.getInstance().then((p) {
      p.setString(_appModeKey, AppMode.worker.name);
      p.setString(_activePositionKey, position);
    });
    notifyListeners();
  }

  /// SMS-tasdiqlash: kod so'raladi. Hozircha SMS provayder ulanmagani uchun
  /// backend kodni javobda ham qaytaradi (`debug_code`) — ekranda shu
  /// ko'rsatiladi (web/iOS bilan bir xil dev-rejim yondashuvi). Backend
  /// qayta yuborishgacha eng kam kutish vaqtini ham qaytaradi
  /// (`resend_after`) — countdown shu qiymatdan boshlanadi.
  Future<OTPRequestResult?> requestOTP(String phone) async {
    errorMessage = null;
    try {
      final resp = await ApiClient.instance.post(
        '/auth/otp/request/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': phone},
        auth: false,
      );
      return OTPRequestResult(
        debugCode: resp['debug_code'] as String?,
        resendAfter: resp['resend_after'] as int? ?? 60,
      );
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Muvaffaqiyatli tasdiqlangach `isNewUser` yangilanadi — birinchi marta
  /// kirgan foydalanuvchidan ism/familiya so'rash kerakligini bildiradi.
  Future<bool> verifyOTP(String phone, String code) async {
    errorMessage = null;
    var ok = false;
    try {
      final resp = await ApiClient.instance.post(
        '/auth/otp/verify/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': phone, 'code': code},
        auth: false,
      );
      final tokens = TokenPair.fromJson(resp);
      isNewUser = resp['is_new_user'] == true;
      _needsRoleCompletion = false; // OTP: registration_completed allaqachon true
      ApiClient.instance.setTokens(tokens);
      _hasStoredTokens = true;
      await _persist(tokens);
      await _loadMe();
      ok = true;
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
    return ok;
  }

  final _googleSignIn = GoogleSignIn(
    // Web Client ID beriladi — shunda native SDK backendimiz tekshira
    // oladigan (`aud` = Web Client ID) ID token qaytaradi (qarang
    // google_auth_config.dart).
    serverClientId: GoogleAuthConfig.webClientId.isEmpty
        ? null
        : GoogleAuthConfig.webClientId,
  );

  /// Google orqali kirish — native Sign-In oqimidan olingan ID token
  /// backendga (`/auth/google/`) yuboriladi, javob boshqa login usullari
  /// bilan bir xil shaklda (`access`/`refresh`/`is_new_user`) keladi.
  Future<bool> loginWithGoogle() async {
    errorMessage = null;
    var ok = false;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false; // foydalanuvchi bekor qildi
      final idToken = (await account.authentication).idToken;
      if (idToken == null) {
        errorMessage = "Google'dan token olinmadi. Qayta urinib ko'ring";
        notifyListeners();
        return false;
      }
      final resp = await ApiClient.instance.post(
        '/auth/google/',
        (j) => j as Map<String, dynamic>,
        body: {'credential': idToken},
        auth: false,
      );
      final tokens = TokenPair.fromJson(resp);
      isNewUser = resp['is_new_user'] == true;
      _needsRoleCompletion = isNewUser;
      _hasStoredTokens = true;
      ApiClient.instance.setTokens(tokens);
      await _persist(tokens);
      await _loadMe();
      ok = true;
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
    return ok;
  }

  /// Telegram orqali kirish — sessiya yaratadi, botni deep-link bilan
  /// (`https://t.me/<bot>?start=<session_id>`) ochadi, so'ng natijani so'rab
  /// turadi (polling). Callback/redirect kerak emas: Telegram bot webhook'i
  /// orqa fonda sessiyani to'ldiradi, biz shu holatni tekshirib turamiz.
  Future<bool> loginWithTelegram() async {
    errorMessage = null;
    try {
      final session = await ApiClient.instance.post(
        '/auth/telegram/session/',
        (j) => j as Map<String, dynamic>,
        auth: false,
      );
      final sessionId = session['session_id'] as String;

      final botInfo = await ApiClient.instance.get(
        '/auth/telegram/bot-info/',
        (j) => j as Map<String, dynamic>,
        auth: false,
      );
      final username = botInfo['username'] as String?;
      if (username == null) {
        errorMessage = "Telegram bot hozircha sozlanmagan";
        notifyListeners();
        return false;
      }

      final opened = await launchUrl(
        Uri.parse('https://t.me/$username?start=$sessionId'),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        errorMessage = "Telegram ochilmadi";
        notifyListeners();
        return false;
      }

      // ~5 daqiqa, 2 soniya oralig'ida — botda "/start" bosilishini kutamiz.
      for (var i = 0; i < 150; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final poll = await ApiClient.instance.get(
          '/auth/telegram/session/$sessionId/',
          (j) => j as Map<String, dynamic>,
          auth: false,
        );
        if (poll['status'] != 'done') continue;

        final tokens = TokenPair.fromJson(poll);
        isNewUser = poll['is_new_user'] == true;
        _needsRoleCompletion = isNewUser;
        ApiClient.instance.setTokens(tokens);
        _hasStoredTokens = true;
        await _persist(tokens);
        await _loadMe();
        notifyListeners();
        return true;
      }
      errorMessage = "Kutish vaqti tugadi. Qayta urinib ko'ring";
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Birinchi marta kirgan foydalanuvchi ismini to'ldirishda ishlatiladi.
  /// Google/Telegram orqali yaratilgan hisob uchun `/complete-registration/`
  /// (rol bilan — mobil ilovada doim "customer"), OTP orqali yaratilgan
  /// hisob uchun oddiy `/users/me/` PATCH (qarang `_needsRoleCompletion`).
  Future<bool> completeProfile({
    required String firstName,
    required String lastName,
    String? dateOfBirth,
  }) async {
    errorMessage = null;
    try {
      AppUser me;
      if (_needsRoleCompletion) {
        final resp = await ApiClient.instance.post(
          '/users/me/complete-registration/',
          (j) => j as Map<String, dynamic>,
          body: {'role': 'customer', 'first_name': firstName, 'last_name': lastName},
          auth: true,
        );
        me = AppUser.fromJson(resp);
        _needsRoleCompletion = false;
        // `/complete-registration/` tug'ilgan kunni qabul qilmaydi (rol/profil
        // uchun mo'ljallangan) — kerak bo'lsa alohida PATCH bilan qo'shamiz.
        if (dateOfBirth != null) {
          me = await ApiClient.instance.patch(
            '/users/me/',
            (j) => AppUser.fromJson(j),
            body: {'date_of_birth': dateOfBirth},
            auth: true,
          );
        }
      } else {
        me = await ApiClient.instance.patch(
          '/users/me/',
          (j) => AppUser.fromJson(j),
          body: {
            'first_name': firstName,
            'last_name': lastName,
            if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          },
          auth: true,
        );
      }
      user = me;
      isNewUser = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokensKey);
    await prefs.remove(_activePositionKey);
    ApiClient.instance.setTokens(null);
    _hasStoredTokens = false;
    user = null;
    isAuthenticated = false;
    appMode = AppMode.customer;
    activePosition = null;
    // Keyingi "Google orqali kirish" bosilganda hisob tanlash oynasi qayta
    // chiqishi uchun — aks holda oxirgi Google hisobiga jimgina kirib qolar edi.
    unawaited(_googleSignIn.signOut());
    notifyListeners();
  }

  Future<void> refreshUser() => _loadMe();

  Future<void> _loadMe() async {
    try {
      final me = await ApiClient.instance.get(
        '/users/me/',
        (j) => AppUser.fromJson(j),
        auth: true,
      );
      user = me;
      isAuthenticated = true;
    } on NetworkException {
      // Internet/serverga ulanib bo'lmadi — bu sessiya eskirgani degani emas.
      // Tokenni saqlab qolamiz (chiqarib yubormaymiz), aloqa tiklanganda
      // keyingi urinishda qayta tekshiriladi. Ilgari muvaffaqiyatli kirilgan
      // bo'lsa, foydalanuvchi hamon "kirgan" holatda qoladi — individual
      // ekranlar o'zi oflayn holatini ko'rsatadi (qarang OfflineView).
      if (user != null) isAuthenticated = true;
    } catch (_) {
      await logout();
      return;
    }
    notifyListeners();
  }

  Future<void> _persist(TokenPair tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokensKey, jsonEncode(tokens.toJson()));
  }
}
