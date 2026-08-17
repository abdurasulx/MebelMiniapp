import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
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
/// [NetworkException]ga, aks holda o'zgarishsiz qayta uloqtiradi — HTTP
/// status kodli javoblar (400/401/500 va h.k.) bunga tegmaydi, chunki ular
/// server ishlab turganini bildiradi.
Future<T> _guardNetwork<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on SocketException {
    throw NetworkException();
  } on TimeoutException {
    throw NetworkException();
  } on http.ClientException {
    throw NetworkException();
  } on HandshakeException {
    throw NetworkException();
  }
}

/// Backend Mac'da ishlab turadi (Asus noutbukda alohida backend ishga
/// tushirish shart emas) — Flutter ilova (Asus'dagi emulyator yoki haqiqiy
/// Android qurilma) Mac'ga **Tailscale VPN tarmog'i** orqali ulanadi (LAN
/// Wi-Fi emas — telefon boshqa tarmoqda/AP-izolyatsiyada bo'lsa ham ishlaydi).
/// Mac va Android qurilma ikkalasida ham Tailscale ilovasi o'rnatilgan va
/// bir xil hisobga kirgan (signed in) holda, doim ishga tushirilgan bo'lishi
/// shart.
///
/// Mac'ning Tailscale IP'si o'zgarsa (kamdan-kam holat), Mac'da
/// `tailscale ip` bilan yangi IP'ni tekshirib, pastdagi qiymatni yangilang
/// (yoki qayta kompilyatsiyasiz:
/// `flutter run --dart-define=API_BASE_URL=http://<yangi-ip>:8000/api/v1`).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://100.69.182.71:8000/api/v1',
  );
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _accessToken;
  String? _refreshToken;
  void Function(TokenPair)? onTokensRotated;

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
    if (imageFieldName != null && imagePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(imageFieldName, imagePath),
      );
    }
    final streamed = await _guardNetwork(
      () => request.send().timeout(const Duration(seconds: 20)),
    );
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(_extractError(resp.body, resp.statusCode));
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

    late http.Response resp;
    final encoded = body != null ? jsonEncode(body) : null;
    resp = await _guardNetwork(() {
      const timeout = Duration(seconds: 12);
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
      throw ApiException(_extractError(resp.body, resp.statusCode));
    }
    if (resp.body.isEmpty) return fromJson(null);
    return fromJson(jsonDecode(resp.body));
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null)
        return decoded['detail'].toString();
      if (decoded is List && decoded.isNotEmpty)
        return decoded.first.toString();
      if (decoded is Map) {
        return decoded.entries.map((e) => '${e.key}: ${e.value}').join('; ');
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
            .timeout(const Duration(seconds: 12)),
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
