import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_locale.dart';
import 'l10n/strings.dart';

/// Til holati — profil ekranidan tanlanadi, qurilmada saqlanadi.
class LocaleStore extends ChangeNotifier {
  static const _prefKey = 'fp.locale';

  String _code = defaultLocaleCode;
  String get code => _code;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _code = prefs.getString(_prefKey) ?? defaultLocaleCode;
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _code = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String t(String key) => tr(_code, key);
}
