import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_signature.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Server umuman javob bermadi (internet yo'q, server o'chiq, DNS
/// topilmadi va h.k.) — bu holatda ekranga xom `SocketException`/
/// `TimeoutException` matnini emas, alohida "oflayn" holatini
/// ko'rsatish kerak (qarang `widgets/offline_view.dart`).
class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Internetga ulanib bo\'lmadi']);
  @override
  String toString() => message;
}

/// Transport darajasidagi xatoni (server umuman topilmadi/javob bermadi)
/// [NetworkException]ga aylantiradi — HTTP status kodli javoblar (400/401/500
/// va h.k.) bunga tegmaydi, chunki ular server ishlab turganini bildiradi.
/// `action` faqat xom HTTP so'rovni bajaradi (`http.get/post/...`), shuning
/// uchun undan chiqadigan HAR QANDAY istisno transport muammosi hisoblanadi —
/// oldin faqat bir nechta aniq tur (`SocketException`/`TimeoutException`/...)
/// ushlanardi, biroq Tailscale VPN qayta ulanish paytida boshqa turdagi
/// (masalan tasodifiy `OSError`/`URI parse` xatolari) istisnolar ham chiqishi
/// mumkin edi — ular ushlanmasdan yuqoriga chiqib, `AuthStore._loadMe()`ning
/// umumiy `catch` blokida "sessiya eskirgan" deb noto'g'ri talqin qilinib,
/// foydalanuvchi bekorga chiqarib yuborilardi. Har bir chaqiruv natijasi
/// (muvaffaqiyat yoki tarmoq xatosi) [ApiClient.isOffline]ni yangilaydi —
/// shu orqali butun ilova (qarang main.dart) global "oflayn" holatini biladi.
Future<T> _guardNetwork<T>(Future<T> Function() action) async {
  try {
    final result = await action();
    ApiClient.instance.isOffline.value = false;
    return result;
  } catch (_) {
    ApiClient.instance.isOffline.value = true;
    throw NetworkException();
  }
}

/// Haqiqiy domen (`https://api.qrbite.uz`) — nginx TLS terminatsiya qilib,
/// backend'ga proksi qiladi. Avval Tailscale VPN orqali Mac'ning IP'siga
/// to'g'ridan-to'g'ri ulanardi (Asus noutbuk/Android qurilma boshqa tarmoqda
/// bo'lsa ham ishlashi uchun), endi hojati yo'q — domen qayerdan bo'lmasin
/// barqaror ishlaydi. Kerak bo'lsa qayta kompilyatsiyasiz almashtirish
/// mumkin: `flutter run --dart-define=API_BASE_URL=<boshqa-manzil>`.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.qrbite.uz/api/v1',
  );
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _accessToken;
  String? _refreshToken;
  void Function(TokenPair)? onTokensRotated;

  /// Global ulanish holati — har qanday so'rov tarmoq xatosiga uchraganda
  /// `true`, muvaffaqiyatli so'rovdan keyin `false` bo'ladi. `main.dart`
  /// shu qiymatni tinglab, oflayn bo'lganda butun ilova (menyu/tablar
  /// bilan birga) o'rniga to'liq ekranli [OfflineView]ni ko'rsatadi.
  final ValueNotifier<bool> isOffline = ValueNotifier(false);

  /// Qayta ulanishni tekshirish uchun yengil so'rov — natijasidan qat'iy
  /// nazar [isOffline] `_guardNetwork` orqali avtomatik yangilanadi.
  Future<void> checkConnectivity() async {
    try {
      await get('/categories/', (j) => j, auth: false);
    } catch (_) {}
  }

  /// Ilova ochilishida (splash paytida) darhol chaqiriladi — oddiy
  /// so'rovlar (VPN kechikishiga chidamli bo'lishi uchun) 6s timeout
  /// ishlatadi, bu birinchi taassurot uchun juda sekin: oflayn holatda
  /// foydalanuvchi splash tugagach ham bir necha soniya "osilib qolgan"
  /// ekranni ko'rardi, oflayn banner esa faqat biror ekran haqiqiy so'rov
  /// yuborib, muddati tugagach paydo bo'lardi. Shu sabab qisqa (2.5s)
  /// timeout bilan alohida, tezkor tekshiruv — natija darhol [isOffline]ga
  /// yoziladi.
  Future<void> probeConnectivity() async {
    try {
      await http
          .get(Uri.parse('${ApiConfig.baseUrl}/categories/'))
          .timeout(const Duration(seconds: 2, milliseconds: 500));
      isOffline.value = false;
    } catch (_) {
      isOffline.value = true;
    }
  }

  void setTokens(TokenPair? tokens) {
    _accessToken = tokens?.access;
    _refreshToken = tokens?.refresh;
  }

  Future<T> get<T>(
    String path,
    T Function(dynamic json) fromJson, {
    bool auth = false,
  }) => _send('GET', path, null, fromJson, auth: auth);

  Future<T> post<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _send('POST', path, body, fromJson, auth: auth);

  Future<T> patch<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _send('PATCH', path, body, fromJson, auth: auth);

  Future<T> delete<T>(
    String path,
    T Function(dynamic json) fromJson, {
    bool auth = true,
  }) => _send('DELETE', path, null, fromJson, auth: auth);

  /// `multipart/form-data` — rasm yuklash kerak bo'lgan amallar uchun
  /// (workflow progress/complete, variant tekstura va h.k.).
  Future<T> postMultipart<T>(
    String path,
    T Function(dynamic json) fromJson, {
    Map<String, String> fields = const {},
    String? imageFieldName,
    String? imagePath,
    bool auth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.fields.addAll(fields);
    if (auth && _accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    request.headers.addAll(DeviceSignature.instance.buildHeaders());
    if (imageFieldName != null && imagePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(imageFieldName, imagePath),
      );
    }
    final streamed = await _guardNetwork(
      () => request.send().timeout(const Duration(seconds: 20)),
    );
    final resp = await http.Response.fromStream(streamed);
    if (request.headers.containsKey('X-Device-Id')) {
      unawaited(DeviceSignature.instance.markSuccess());
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(_extractError(resp.body, resp.statusCode), statusCode: resp.statusCode);
    }
    return fromJson(jsonDecode(resp.body));
  }

  Future<T> _send<T>(
    String method,
    String path,
    Map<String, dynamic>? body,
    T Function(dynamic json) fromJson, {
    required bool auth,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    // Qo'shimcha so'rov-imzosi (HMAC) — qarang device_signature.dart /
    // apps/notifications/security.py (nwupdate.md).
    headers.addAll(DeviceSignature.instance.buildHeaders());

    late http.Response resp;
    final encoded = body != null ? jsonEncode(body) : null;
    resp = await _guardNetwork(() {
      // 3s juda tez edi — mobil tarmoqda (ayniqsa Tailscale VPN orqali)
      // oddiy kechikish ham "oflayn" deb noto'g'ri aniqlanib, endi
      // zararsiz bo'lsa ham (RootScreen'ni yo'q qilmaydi) keraksiz
      // to'liq ekranli uzilishlarni keltirib chiqarardi.
      const timeout = Duration(seconds: 6);
      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          return http.post(uri, headers: headers, body: encoded).timeout(timeout);
        case 'PATCH':
          return http.patch(uri, headers: headers, body: encoded).timeout(timeout);
        case 'DELETE':
          return http.delete(uri, headers: headers).timeout(timeout);
        default:
          throw ApiException('Noma\'lum HTTP metod: $method');
      }
    });

    // Qurilma-imzosi headerlari yuborilgan bo'lsa, server nechta status
    // qaytarmasin (device-imzo o'zi 400/401/403 bilan aniq rad etadi),
    // "so'nggi urinish" vaqtini yangilaymiz — shu bilan keyingi so'rovning
    // `day_delta`si serverning kutayotgan qiymatiga qayta moslanadi (agar
    // avval qandaydir sabab bilan chalkashib qolgan bo'lsa ham).
    if (headers.containsKey('X-Device-Id')) {
      unawaited(DeviceSignature.instance.markSuccess());
    }

    if (resp.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _refreshAccessToken();
      if (refreshed == true) {
        return _send(method, path, body, fromJson, auth: auth, isRetry: true);
      }
      if (refreshed == null) {
        // Yangilash so'rovi tarmoq xatosi bilan muvaffaqiyatsiz tugadi —
        // sessiya haqiqatan ham eskirganini bilmaymiz, shuning uchun bu
        // holatni "chiqib ketilgan" emas, "oflayn" deb hisoblaymiz (token
        // saqlanib qoladi, keyingi urinishda qayta tekshiriladi).
        throw NetworkException();
      }
      // refreshed == false: refresh tokeni haqiqatan ham eskirgan/yaroqsiz —
      // pastda asl 401 javobi bo'yicha ApiException tashlanadi.
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(_extractError(resp.body, resp.statusCode), statusCode: resp.statusCode);
    }
    if (resp.body.isEmpty) return fromJson(null);
    return fromJson(jsonDecode(resp.body));
  }

  // Backend (DRF) `ValidationError("xabar")` ko'targanda `detail`ni matn
  // EMAS, ro'yxat sifatida qaytaradi (`{"detail": ["xabar"]}` — DRF'ning
  // o'zi shunday normallashtiradi). Shuni hisobga olmasa, xato matni
  // o'rniga "[xabar]" kabi qavsli chiqindi ko'rinardi.
  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is List && detail.isNotEmpty) return detail.first.toString();
        return detail.toString();
      }
      if (decoded is List && decoded.isNotEmpty)
        return decoded.first.toString();
      if (decoded is Map) {
        // Serializer maydon xatolari — masalan {"phone": ["Bu maydon
        // bo'sh bo'lmasligi kerak."]} — qiymatlar ro'yxat bo'lgani uchun
        // qavssiz, o'qilishi qulay ko'rinishga birlashtiriladi.
        return decoded.entries.map((e) {
          final v = e.value;
          final text = v is List ? v.join(', ') : v.toString();
          return '${e.key}: $text';
        }).join('; ');
      }
    } catch (_) {}
    return 'Xatolik ($statusCode)';
  }

  /// `true` — yangilandi. `false` — refresh tokeni haqiqatan ham yaroqsiz
  /// (chiqib ketish kerak). `null` — tarmoq xatosi bilan tekshirib
  /// bo'lmadi (oflayn — chiqib yubormaslik kerak, keyinroq qayta urinamiz).
  Future<bool?> _refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/token/refresh/');
      final resp = await _guardNetwork(
        () => http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh': _refreshToken}),
            )
            .timeout(const Duration(seconds: 6)),
      );
      if (resp.statusCode != 200) return false;
      final decoded = jsonDecode(resp.body);
      _accessToken = decoded['access'];
      // ROTATE_REFRESH_TOKENS=True bo'lgani uchun javobda yangi refresh ham kelishi mumkin.
      if (decoded['refresh'] != null) {
        _refreshToken = decoded['refresh'];
        onTokensRotated?.call(
          TokenPair(access: _accessToken!, refresh: _refreshToken!),
        );
      }
      return true;
    } on NetworkException {
      return null;
    } catch (_) {
      return false;
    }
  }
}
