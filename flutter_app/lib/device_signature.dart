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
  static const _kRegistered = 'device_signature_registered';

  // Backend'dagi DEVICE_HMAC_SECRET (`.env`) bilan BIR XIL bo'lishi SHART —
  // aks holda HAR BIR imzo SIGNATURE_INVALID bilan rad etiladi (aynan shu
  // sabab bilan sinovda muvaffaqiyatsiz bo'lgan edi). Prodda build vaqtida
  // `--dart-define=DEVICE_HMAC_SECRET=...` bilan almashtirish tavsiya
  // etiladi, lekin standart qiymat backend bilan HOZIRDA mos.
  static const String _secret = String.fromEnvironment(
    'DEVICE_HMAC_SECRET',
    defaultValue: 'Vida7kQ3mN9pXr2LsT8wZcF5hJyU4bE6',
  );

  String? _deviceId;
  String _deviceName = 'Android';
  int _vcode = 0;
  DateTime? _lastUpdated;
  bool _registered = false;

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
    _registered = prefs.getBool(_kRegistered) ?? false;

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

  /// Har bir HTTP so'roviga qo'shiladigan headerlar to'plami. Qurilma
  /// hali backend'da RO'YXATDAN O'TMAGAN bo'lsa (`_registered == false` —
  /// masalan yangi o'rnatilgan ilova, `register_device` hali tugallanmagan)
  /// bo'sh xarita qaytaradi — aks holda ilova ochilishida parallel ketayotgan
  /// BOSHQA so'rovlar (bootstrap, catalog va h.k.) `register_device`dan
  /// OLDIN backend'ga signature bilan yetib borib, hali mavjud bo'lmagan
  /// qurilma uchun "DEVICE_REVOKED" xatosi bilan rad etilar edi (haqiqiy
  /// bekor qilinganidan emas, shunchaki hali ro'yxatdan o'tmaganidan).
  Map<String, String> buildHeaders() {
    final deviceId = _deviceId;
    if (deviceId == null || !_registered) return const {};

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

  /// `register_device` MUVAFFAQIYATLI tugagach chaqiriladi (qarang
  /// `push_service.dart::_sendToken`) — shundan keyingina so'rovlarga
  /// imzo qo'shila boshlaydi (yuqoridagi `buildHeaders` izohiga qarang).
  Future<void> markRegistered() async {
    if (_registered) return;
    _registered = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRegistered, true);
    await markSuccess();
  }

  /// Logout bo'lganda chaqiriladi — backend qurilma yozuvini butunlay
  /// o'chiradi (`unregister_device`), shuning uchun mahalliy holat ham
  /// "ro'yxatdan o'tmagan"ga qaytariladi — aks holda keyingi so'rovlar
  /// mavjud bo'lmagan qurilma uchun imzolab yuborilib, DEVICE_REVOKED bilan
  /// rad etilar edi (keyingi login `register_device`ni qayta chaqirganda
  /// tuzatiladi, lekin shu oraliqda keraksiz xatolar chiqmasligi uchun).
  Future<void> markUnregistered() async {
    _registered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRegistered, false);
  }

  String get deviceName => _deviceName;
  int get vcode => _vcode;
}
