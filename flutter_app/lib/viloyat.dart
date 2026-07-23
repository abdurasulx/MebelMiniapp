import 'dart:math' as math;

/// O'zbekiston viloyatlari — backend `Viloyat` enum bilan bir xil kodlar
/// (`backend/apps/companies/models.py`). GPS koordinatasidan eng yaqin
/// viloyat markazini topish uchun taxminiy markaz koordinatalari beriladi
/// (aniq chegara emas, shunchaki eng yaqin markazni tanlash uslubi —
/// tashqi geocoding xizmati/API kaliti kerak emas).
class ViloyatInfo {
  final String code;
  final String label;
  final double lat;
  final double lng;
  const ViloyatInfo(this.code, this.label, this.lat, this.lng);
}

const List<ViloyatInfo> viloyatlar = [
  ViloyatInfo('toshkent_shahri', "Toshkent shahri", 41.2995, 69.2401),
  ViloyatInfo('toshkent_viloyati', "Toshkent viloyati", 41.0, 69.5),
  ViloyatInfo('andijon', "Andijon", 40.7821, 72.3442),
  ViloyatInfo('buxoro', "Buxoro", 39.7747, 64.4286),
  ViloyatInfo('fargona', "Farg'ona", 40.3894, 71.7864),
  ViloyatInfo('jizzax', "Jizzax", 40.1158, 67.8422),
  ViloyatInfo('xorazm', "Xorazm", 41.3775, 60.3639),
  ViloyatInfo('namangan', "Namangan", 40.9983, 71.6726),
  ViloyatInfo('navoiy', "Navoiy", 40.1030, 65.3686),
  ViloyatInfo('qashqadaryo', "Qashqadaryo", 38.8606, 65.7891),
  ViloyatInfo(
    'qoraqalpogiston',
    "Qoraqalpog'iston Respublikasi",
    42.4531,
    59.6103,
  ),
  ViloyatInfo('samarqand', "Samarqand", 39.6270, 66.9750),
  ViloyatInfo('sirdaryo', "Sirdaryo", 40.5030, 68.7842),
  ViloyatInfo('surxondaryo', "Surxondaryo", 37.9401, 67.5714),
];

String viloyatLabel(String? code) {
  if (code == null) return "Barchasi";
  return viloyatlar
      .firstWhere(
        (v) => v.code == code,
        orElse: () => const ViloyatInfo('', "Noma'lum", 0, 0),
      )
      .label;
}

double _deg2rad(double deg) => deg * (math.pi / 180);

/// Haversine masofasi (km) — koordinatani eng yaqin viloyat markaziga
/// bog'lash uchun yetarli darajada aniq.
double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);
  final a =
      sinDLat * sinDLat +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) * sinDLng * sinDLng;
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Berilgan lat/lng ga eng yaqin viloyatni topadi.
ViloyatInfo nearestViloyat(double lat, double lng) {
  ViloyatInfo best = viloyatlar.first;
  double bestDist = double.infinity;
  for (final v in viloyatlar) {
    final d = _distanceKm(lat, lng, v.lat, v.lng);
    if (d < bestDist) {
      bestDist = d;
      best = v;
    }
  }
  return best;
}
