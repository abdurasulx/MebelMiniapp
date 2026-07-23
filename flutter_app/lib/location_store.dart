import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'viloyat.dart';

enum LocationStatus { idle, loading, granted, denied, unavailable }

/// GPS orqali foydalanuvchi qaysi viloyatda ekanini aniqlaydi — bir necha
/// viloyatda filiali bor firmalarning shu viloyatga tegishli mahsulotlarini
/// ko'rsatish uchun (`Product.branch_viloyat` filtri, backend `?viloyat=`).
/// Foydalanuvchi xohlasa katalogdan qo'lda "Barchasi"ga o'tishi ham mumkin.
class LocationStore extends ChangeNotifier {
  static const _prefKey = 'selected_viloyat';

  String? _viloyat; // null = "Barchasi" (filtrsiz)
  LocationStatus _status = LocationStatus.idle;

  String? get viloyat => _viloyat;
  LocationStatus get status => _status;
  String get viloyatLabelText => viloyatLabel(_viloyat);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _viloyat = saved;
      _status = LocationStatus.granted;
      notifyListeners();
      return;
    }
    await detectFromGps();
  }

  Future<void> detectFromGps() async {
    _status = LocationStatus.loading;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _status = LocationStatus.unavailable;
        notifyListeners();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _status = LocationStatus.denied;
        notifyListeners();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
      final nearest = nearestViloyat(position.latitude, position.longitude);
      await setViloyat(nearest.code);
      _status = LocationStatus.granted;
    } catch (_) {
      _status = LocationStatus.unavailable;
    }
    notifyListeners();
  }

  Future<void> setViloyat(String? code) async {
    _viloyat = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, code);
    }
  }
}
