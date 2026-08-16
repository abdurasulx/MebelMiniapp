import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_locale.dart';
import 'l10n/strings.dart';

/// Til holati — profil ekranidan tanlanadi, qurilmada saqlanadi. Birinchi
/// marta ochilganda (hali qo'lda tanlanmagan bo'lsa) qurilma tiliga qarab
/// avtomatik aniqlanadi — qo'llab-quvvatlanmasa "O'zbekcha"ga qaytadi.
class LocaleStore extends ChangeNotifier {
  static const _prefKey = 'fp.locale';

  String _code = defaultLocaleCode;
  String get code => _code;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _code = saved ?? _detectDeviceLocale();
    notifyListeners();
  }

  String _detectDeviceLocale() {
    for (final deviceLocale in ui.PlatformDispatcher.instance.locales) {
      for (final supported in supportedLocales) {
        if (supported.code == deviceLocale.languageCode) return supported.code;
      }
    }
    return defaultLocaleCode;
  }

  Future<void> setLocale(String code) async {
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String t(String key) => tr(_code, key);
}
