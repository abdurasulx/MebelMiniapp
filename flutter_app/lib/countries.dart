/// MDH davlatlari — telefon raqami kiritishdan oldin davlat tanlash uchun
/// (davlat kodi + bayroq emoji + nom). Backend `PhoneOTP`/`User.phone`
/// har qanday formatdagi qatorni qabul qiladi, shuning uchun bu yerda faqat
/// UI darajasida raqamga kod qo'shib beriladi va uzunligi tekshiriladi
/// (davlat kodidan keyingi mahalliy raqam necha xonali bo'lishi kerak).
class CountryInfo {
  final String name;
  final String dialCode;
  final String flag;
  final int phoneLength;
  const CountryInfo(this.name, this.dialCode, this.flag, this.phoneLength);

  bool isValid(String localNumber) =>
      RegExp(r'^\d+$').hasMatch(localNumber) &&
      localNumber.length == phoneLength;
}

const List<CountryInfo> cisCountries = [
  CountryInfo("O'zbekiston", '+998', '🇺🇿', 9),
  CountryInfo('Rossiya', '+7', '🇷🇺', 10),
  CountryInfo("Qozog'iston", '+7', '🇰🇿', 10),
  CountryInfo("Qirg'iziston", '+996', '🇰🇬', 9),
  CountryInfo('Tojikiston', '+992', '🇹🇯', 9),
  CountryInfo('Turkmaniston', '+993', '🇹🇲', 8),
  CountryInfo('Ozarbayjon', '+994', '🇦🇿', 9),
  CountryInfo('Armaniston', '+374', '🇦🇲', 8),
  CountryInfo('Belarus', '+375', '🇧🇾', 9),
  CountryInfo('Moldova', '+373', '🇲🇩', 8),
];
