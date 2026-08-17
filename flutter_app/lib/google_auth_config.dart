/// Google Cloud Console'dagi **Web application** turidagi OAuth Client ID
/// (backend `.env`dagi `GOOGLE_CLIENT_ID`, frontend `.env`dagi
/// `VITE_GOOGLE_CLIENT_ID` bilan bir xil qiymat).
///
/// Bu qiymat Android/iOS'dagi native Google Sign-In oqimiga `serverClientId`
/// sifatida beriladi — shu orqali native SDK backendimiz tekshira oladigan
/// (audience = Web Client ID) ID token qaytaradi, garchi kirish o'zi
/// platformaning o'z (Android/iOS) OAuth clientlari orqali amalga oshsa ham.
/// Web Client ID maxfiy emas (frontend bundle'ida ham ochiq turibdi),
/// shuning uchun standart qiymat sifatida shu yerga yozilgan — kerak bo'lsa
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=...` bilan ustidan yozish mumkin.
class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '857603145763-27ohksib2icfvlstl877bchjo4ti6563.apps.googleusercontent.com',
  );
}
