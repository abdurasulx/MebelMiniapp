import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

/// Bitta "Ishga keldim"/"Ishni tugatdim" bosishi natijasi — backend
/// qarorini (`AttendanceRecord`) o'zida saqlaydi (qarang
/// apps.attendance.services.resolve_check_in).
class AttendanceResult {
  final String status; // approved / rejected / suspicious
  final String reason;
  final String action;

  AttendanceResult({required this.status, required this.reason, required this.action});

  bool get isApproved => status == 'approved';

  factory AttendanceResult.fromJson(Map<String, dynamic> j) => AttendanceResult(
        status: j['status'] ?? '',
        reason: j['reason'] ?? '',
        action: j['action'] ?? '',
      );
}

/// Xatolik turlari — geolokatsiya olishning o'zida muvaffaqiyatsizlik
/// (backend hali chaqirilmagan holat), backend javobidan farqli.
class AttendanceLocationException implements Exception {
  final String message;
  AttendanceLocationException(this.message);
  @override
  String toString() => message;
}

/// Xodimning "Ishga keldim"/"Ishni tugatdim" amali — qurilma geolokatsiyasini
/// oladi (shu jumladan Android'ning mock-location bayrog'ini), backendga
/// yuboradi va YAKUNIY qarorni (tasdiqlangan/rad etilgan/shubhali) qaytaradi.
/// Play Integrity token — hozircha alohida native integratsiya
/// ulanmagunicha `null` yuboriladi, backend buni "sozlanmagan" deb
/// belgilaydi (check-in rad etilmaydi).
class AttendanceStore {
  Future<Position> _currentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw AttendanceLocationException(
        'Joylashuvga ruxsat berilmagan. Sozlamalardan ruxsat bering.',
      );
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw AttendanceLocationException('Joylashuv xizmati o\'chirilgan.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      throw AttendanceLocationException('Joylashuv aniqlanmadi. Qayta urining.');
    }
  }

  Future<AttendanceResult> _submit(String endpoint) async {
    final position = await _currentPosition();
    final json = await ApiClient.instance.post(
      '/attendance/records/$endpoint/',
      (j) => j as Map<String, dynamic>,
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'device_timestamp': position.timestamp.toIso8601String(),
        'is_mock': position.isMocked,
        'platform': 'android',
      },
      auth: true,
    );
    return AttendanceResult.fromJson(json);
  }

  Future<AttendanceResult> checkIn() => _submit('check_in');
  Future<AttendanceResult> checkOut() => _submit('check_out');
}
