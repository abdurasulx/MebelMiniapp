import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'locale_store.dart';
import 'viloyat.dart';

enum LocationStatus { idle, loading, granted, denied, unavailable }

/// GPS orqali foydalanuvchi qaysi viloyatda ekanini aniqlaydi — o'sha
/// viloyatdagi (yoki viloyati ko'rsatilmagan) firmalarning mahsulotlarini
/// ko'rsatish uchun (`Product.company_viloyat` filtri, backend `?viloyat=`).
/// Foydalanuvchi xohlasa katalogdan qo'lda "Barchasi"ga o'tishi ham mumkin.
class LocationStore extends ChangeNotifier {
  static const _prefKey = 'selected_viloyat';
  static const _latKey = 'gps_lat';
  static const _lngKey = 'gps_lng';

  String? _viloyat; // null = "Barchasi" (filtrsiz)
  double? _lat;
  double? _lng;
  LocationStatus _status = LocationStatus.idle;

  String? get viloyat => _viloyat;
  // Aniq GPS koordinatasi — mavjud bo'lsa, firma xizmat radiusi bo'yicha
  // filtrlashda viloyat o'rniga shu ishlatiladi (qarang apps/products/views.py
  // `lat`/`lng` parametri, backend/common/geo.py).
  double? get lat => _lat;
  double? get lng => _lng;
  LocationStatus get status => _status;
  String viloyatLabelText(LocaleStore loc) => viloyatLabel(_viloyat, loc);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final savedLat = prefs.getDouble(_latKey);
    final savedLng = prefs.getDouble(_lngKey);
    if (saved != null) {
      _viloyat = saved;
      _lat = savedLat;
      _lng = savedLng;
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
      await setViloyat(nearest.code, lat: position.latitude, lng: position.longitude);
      _status = LocationStatus.granted;
    } catch (_) {
      _status = LocationStatus.unavailable;
    }
    notifyListeners();
  }

  Future<void> setViloyat(String? code, {double? lat, double? lng}) async {
    _viloyat = code;
    // Qo'lda boshqa viloyat tanlansa, avvalgi GPS koordinatasi endi noto'g'ri
    // bo'lib qoladi — shuning uchun faqat GPS orqali kelgan chaqiruvdagina
    // (lat/lng berilganda) saqlanadi, aks holda tozalanadi.
    _lat = lat;
    _lng = lng;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, code);
    }
    if (lat != null && lng != null) {
      await prefs.setDouble(_latKey, lat);
      await prefs.setDouble(_lngKey, lng);
    } else {
      await prefs.remove(_latKey);
      await prefs.remove(_lngKey);
    }
  }
}
