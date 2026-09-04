import 'package:flutter/material.dart';
import 'locale_store.dart';

/// Mebel firmasi xodim kasblari — backend `Employee.Position` bilan bir xil
/// (web: `frontend/src/positions.js`ga mos).
class PositionInfo {
  final String label;
  final IconData icon;
  final String desc;
  const PositionInfo(this.label, this.icon, this.desc);
}

const Map<String, IconData> _kPositionIcons = {
  'usta': Icons.handyman_rounded,
  'sotuvchi': Icons.shopping_cart_rounded,
  'ornatuvchi': Icons.build_rounded,
  'dizayner': Icons.palette_rounded,
  'omborchi': Icons.inventory_2_rounded,
  'haydovchi': Icons.local_shipping_rounded,
  'menejer': Icons.assignment_rounded,
};

/// Tanlangan tilga mos kasb nomi/tavsifi — `loc`dan `position_<key>` va
/// `position_<key>_desc` kalitlari orqali olinadi, mos kalit topilmasa
/// (masalan yangi/noma'lum kasb) xom `key` o'zi ko'rsatiladi.
PositionInfo positionInfo(String key, LocaleStore loc) {
  final icon = _kPositionIcons[key] ?? Icons.badge_rounded;
  if (!_kPositionIcons.containsKey(key)) {
    return PositionInfo(key, icon, '');
  }
  return PositionInfo(loc.t('position_$key'), icon, loc.t('position_${key}_desc'));
}
