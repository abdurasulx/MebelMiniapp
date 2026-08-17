/// Google Cloud Console'dagi **Web application** turidagi OAuth Client ID
/// (backend `.env`dagi `GOOGLE_CLIENT_ID` bilan bir xil qiymat).
///
/// Bu qiymat Android/iOS'dagi native Google Sign-In oqimiga `serverClientId`
/// sifatida beriladi — shu orqali native SDK backendimiz tekshira oladigan
/// (audience = Web Client ID) ID token qaytaradi, garchi kirish o'zi
/// platformaning o'z (Android/iOS) OAuth clientlari orqali amalga oshsa ham.
///
/// Qiymat kompilyatsiya vaqtida beriladi (build-secret sifatida saqlanmaydi):
/// `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<client-id>.apps.googleusercontent.com`
class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
