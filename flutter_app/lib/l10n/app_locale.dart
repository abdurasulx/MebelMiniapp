/// Qo'llab-quvvatlanadigan tillar (profil ekranidan tanlanadi). Hozircha
/// asosiy navigatsiya/kirish/savat matnlari tarjima qilingan — qolgan
/// ekranlar bosqichma-bosqich qo'shiladi (`lib/l10n/strings.dart`).
class AppLocale {
  final String code;
  final String nativeName;
  const AppLocale(this.code, this.nativeName);
}

const List<AppLocale> supportedLocales = [
  AppLocale('uz', "O'zbekcha"),
  AppLocale('en', 'English'),
  AppLocale('ru', 'Русский'),
  AppLocale('tg', 'Тоҷикӣ'),
  AppLocale('tr', 'Türkçe'),
  AppLocale('ky', 'Кыргызча'),
  AppLocale('kk', 'Қазақша'),
  AppLocale('de', 'Deutsch'),
  AppLocale('az', 'Azərbaycan'),
];

const String defaultLocaleCode = 'uz';
