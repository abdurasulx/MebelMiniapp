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

  String timeAgo(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return t('time_just_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}${t('time_min_ago')}';
    if (diff.inHours < 24) return '${diff.inHours}${t('time_hours_ago')}';
    return '${diff.inDays}${t('time_days_ago')}';
  }

  static const Map<String, List<String>> _monthNames = {
    'uz': ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun', 'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'],
    'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
    'ru': ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
    'tg': ['Январ', 'Феврал', 'Март', 'Апрел', 'Май', 'Июн', 'Июл', 'Август', 'Сентябр', 'Октябр', 'Ноябр', 'Декабр'],
    'tr': ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
    'ky': ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
    'kk': ['Қаңтар', 'Ақпан', 'Наурыз', 'Сәуір', 'Мамыр', 'Маусым', 'Шілде', 'Тамыз', 'Қыркүйек', 'Қазан', 'Қараша', 'Желтоқсан'],
    'de': ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'],
    'az': ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'İyun', 'İyul', 'Avqust', 'Sentyabr', 'Oktyabr', 'Noyabr', 'Dekabr'],
  };

  String monthName(int month) {
    final list = _monthNames[_code] ?? _monthNames['uz']!;
    if (month < 1 || month > 12) return '';
    return list[month - 1];
  }

  String periodLabel(String period) {
    final parts = period.split('-');
    if (parts.length < 2) return period;
    final m = int.tryParse(parts[1]);
    if (m == null || m < 1 || m > 12) return period;
    return '${monthName(m)} ${parts[0]}';
  }
}
