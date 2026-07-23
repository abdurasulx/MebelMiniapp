import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
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

  static const _tokensKey = 'fp.tokens';
  static const _appModeKey = 'fp.appMode';

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_appModeKey);
    if (savedMode == 'worker') appMode = AppMode.worker;

    final raw = prefs.getString(_tokensKey);
    if (raw != null) {
      final tokens = TokenPair.fromJson(jsonDecode(raw));
      ApiClient.instance.setTokens(tokens);
      ApiClient.instance.onTokensRotated = _persist;
      await _loadMe();
    }
    notifyListeners();
  }

  void setAppMode(AppMode mode) {
    appMode = mode;
    SharedPreferences.getInstance().then(
      (p) => p.setString(_appModeKey, mode.name),
    );
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

  /// Birinchi marta kirgan foydalanuvchi ismini to'ldirishda ishlatiladi.
  Future<bool> completeProfile({
    required String firstName,
    required String lastName,
    String? dateOfBirth,
  }) async {
    errorMessage = null;
    try {
      final me = await ApiClient.instance.patch(
        '/users/me/',
        (j) => AppUser.fromJson(j),
        body: {
          'first_name': firstName,
          'last_name': lastName,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        },
        auth: true,
      );
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
    ApiClient.instance.setTokens(null);
    user = null;
    isAuthenticated = false;
    appMode = AppMode.customer;
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
