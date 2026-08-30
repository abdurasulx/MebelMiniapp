import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backend'dagi qo'shimcha xavfsizlik qatlami (nwupdate.md §4-10) uchun
/// mijoz tomoni — har bir API so'roviga HMAC-SHA256 imzo + `day_delta` +
/// `timesnap` + `nonce` headerlarini qo'shadi (qarang `api_client.dart`,
/// `apps/notifications/security.py`).
///
/// MUHIM: bu APK ichidagi "sir" reverse-engineering'dan himoyalanmagan —
/// asosiy xavfsizlik BARIBIR Access/Refresh Token orqali ta'minlanadi, bu
/// faqat qo'shimcha (replay/tampering'ni qiyinlashtiruvchi) qatlam.
class DeviceSignature {
  DeviceSignature._();
  static final DeviceSignature instance = DeviceSignature._();

  static const _kDeviceId = 'device_signature_id';
  static const _kLastUpdated = 'device_signature_last_updated_ms';

  // Backend'dagi DEVICE_HMAC_SECRET bilan BIR XIL bo'lishi shart (`.env`da
  // sozlanadi). Prodda build vaqtida `--dart-define=DEVICE_HMAC_SECRET=...`
  // orqali almashtirilishi tavsiya etiladi.
  static const String _secret = String.fromEnvironment(
    'DEVICE_HMAC_SECRET',
    defaultValue: 'dev-only-change-me',
  );

  String? _deviceId;
  String _deviceName = 'Android';
  int _vcode = 0;
  DateTime? _lastUpdated;

  String? get deviceId => _deviceId;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceId);
    if (_deviceId == null) {
      _deviceId = _randomHex();
      await prefs.setString(_kDeviceId, _deviceId!);
    }
    final lastMs = prefs.getInt(_kLastUpdated);
    _lastUpdated = lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null;

    try {
      final info = await PackageInfo.fromPlatform();
      _deviceName = 'Android ${info.version}';
      _vcode = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      // PackageInfo muvaffaqiyatsiz bo'lsa ham (kamdan-kam), imzo hisoblash
      // standart qiymatlar bilan davom etadi.
    }
  }

  String _randomHex([int bytes = 16]) {
    final rand = Random.secure();
    return List.generate(bytes, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Har bir HTTP so'roviga qo'shiladigan headerlar to'plami. `_deviceId`
  /// hali tayyor bo'lmasa (masalan `init()` chaqirilmagan bo'lsa) bo'sh
  /// xarita qaytaradi — chaqiruvchi (`ApiClient`) shu holda headerlarni
  /// oddiy qo'shmaydi, so'rov IMZOSIZ ketadi (server bunday so'rovni
  /// `X-Device-Id` yo'qligi sababli oddiy — imzosiz — deb qabul qiladi).
  Map<String, String> buildHeaders() {
    final deviceId = _deviceId;
    if (deviceId == null) return const {};

    final now = DateTime.now();
    final dayDelta = _lastUpdated == null ? 0 : _daysBetween(_lastUpdated!, now);
    final timesnap = now.millisecondsSinceEpoch ~/ 1000 ~/ 300;
    final nonce = _randomHex(12);

    final payload = '$deviceId:$_deviceName:$_vcode:$dayDelta:$timesnap:$nonce';
    final signature = Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode(payload)).toString();

    return {
      'X-Device-Id': deviceId,
      'X-Dev-Name': _deviceName,
      'X-Vcode': '$_vcode',
      'X-Day-Delta': '$dayDelta',
      'X-Timesnap': '$timesnap',
      'X-Nonce': nonce,
      'X-Signature': signature,
    };
  }

  int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// So'rov MUVAFFAQIYATLI qabul qilingach (401/403 emas) chaqiriladi —
  /// server `last_seen`sini mahalliy tarzda ko'zguga oladi, shunda
  /// KEYINGI so'rovning `day_delta`si serverning kutgan qiymati bilan
  /// mos keladi (qarang apps/notifications/security.py::validate_request).
  Future<void> markSuccess() async {
    _lastUpdated = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastUpdated, _lastUpdated!.millisecondsSinceEpoch);
  }

  String get deviceName => _deviceName;
  int get vcode => _vcode;
}
