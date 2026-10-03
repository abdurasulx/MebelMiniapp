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
  bool _permanentlyDenied = false;

  String? get viloyat => _viloyat;
  // Aniq GPS koordinatasi — mavjud bo'lsa, firma xizmat radiusi bo'yicha
  // filtrlashda viloyat o'rniga shu ishlatiladi (qarang apps/products/views.py
  // `lat`/`lng` parametri, backend/common/geo.py).
  double? get lat => _lat;
  double? get lng => _lng;
  LocationStatus get status => _status;
  bool get permanentlyDenied => _permanentlyDenied;
  /// Mahsulotlarni ko'rsatish uchun yangi GPS koordinatasi bor.
  bool get hasFix => _status == LocationStatus.granted && _lat != null && _lng != null;

  /// Ruxsat berilmagan/GPS o'chiq holatda tegishli tizim sozlamasini ochadi.
  Future<void> openSettings() async {
    if (_status == LocationStatus.unavailable) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
  String viloyatLabelText(LocaleStore loc) => viloyatLabel(_viloyat, loc);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // Saqlangan viloyatni (savat/yetkazib berish uchun) tiklaymiz, lekin
    // KOORDINATANI emas — mahsulotlar ko'rinishi har safar ilova ochilganda
    // yangi GPS o'lchovi bilan hal qilinadi (eskirgan joy bilan boshqa
    // shahardagi firma mahsulotlari ko'rinib qolmasligi uchun).
    _viloyat = prefs.getString(_prefKey);
    await detectFromGps();
  }

  Future<void> detectFromGps() async {
    _status = LocationStatus.loading;
    notifyListeners();
    try {
      _lat = null;
      _lng = null;
      _permanentlyDenied = false;
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
        _permanentlyDenied = permission == LocationPermission.deniedForever;
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
