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

class AuthStore extends ChangeNotifier {
  AppUser? user;
  bool isAuthenticated = false;
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

  Future<void> login(String email, String password) async {
    errorMessage = null;
    try {
      final tokens = await ApiClient.instance.post(
        '/auth/token/',
        (j) => TokenPair.fromJson(j),
        body: {'email': email, 'password': password},
        auth: false,
      );
      ApiClient.instance.setTokens(tokens);
      await _persist(tokens);
      await _loadMe();
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> register(
    String email,
    String password,
    String firstName,
    String phone,
  ) async {
    errorMessage = null;
    try {
      await ApiClient.instance.post(
        '/auth/register/',
        (j) => j,
        body: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'phone': phone,
          'role': 'customer',
        },
        auth: false,
      );
      await login(email, password);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// SMS-tasdiqlash: kod so'raladi. Hozircha SMS provayder ulanmagani uchun
  /// backend kodni javobda ham qaytaradi (`debug_code`) — ekranda shu
  /// ko'rsatiladi (web/iOS bilan bir xil dev-rejim yondashuvi).
  Future<String?> requestOTP(String phone) async {
    errorMessage = null;
    try {
      final resp = await ApiClient.instance.post(
        '/auth/otp/request/',
        (j) => j as Map<String, dynamic>,
        body: {'phone': phone},
        auth: false,
      );
      return resp['debug_code'] as String?;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> verifyOTP(String phone, String code) async {
    errorMessage = null;
    try {
      final tokens = await ApiClient.instance.post(
        '/auth/otp/verify/',
        (j) => TokenPair.fromJson(j),
        body: {'phone': phone, 'code': code},
        auth: false,
      );
      ApiClient.instance.setTokens(tokens);
      await _persist(tokens);
      await _loadMe();
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
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
