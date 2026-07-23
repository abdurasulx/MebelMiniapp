/// MDH davlatlari — telefon raqami kiritishdan oldin davlat tanlash uchun
/// (davlat kodi + bayroq emoji + nom). Backend `PhoneOTP`/`User.phone`
/// har qanday formatdagi qatorni qabul qiladi, shuning uchun bu yerda faqat
/// UI darajasida raqamga kod qo'shib beriladi.
class CountryInfo {
  final String name;
  final String dialCode;
  final String flag;
  const CountryInfo(this.name, this.dialCode, this.flag);
}

const List<CountryInfo> cisCountries = [
  CountryInfo("O'zbekiston", '+998', '🇺🇿'),
  CountryInfo('Rossiya', '+7', '🇷🇺'),
  CountryInfo("Qozog'iston", '+7', '🇰🇿'),
  CountryInfo("Qirg'iziston", '+996', '🇰🇬'),
  CountryInfo('Tojikiston', '+992', '🇹🇯'),
  CountryInfo('Turkmaniston', '+993', '🇹🇲'),
  CountryInfo('Ozarbayjon', '+994', '🇦🇿'),
  CountryInfo('Armaniston', '+374', '🇦🇲'),
  CountryInfo('Belarus', '+375', '🇧🇾'),
  CountryInfo('Moldova', '+373', '🇲🇩'),
];
