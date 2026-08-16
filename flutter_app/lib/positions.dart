import 'package:flutter/material.dart';

/// Mebel firmasi xodim kasblari — backend `Employee.Position` bilan bir xil
/// (web: `frontend/src/positions.js`ga mos).
class PositionInfo {
  final String label;
  final IconData icon;
  final String desc;
  const PositionInfo(this.label, this.icon, this.desc);
}

const Map<String, PositionInfo> kPositions = {
  'usta': PositionInfo('Usta', Icons.handyman_rounded, 'Ishlab chiqarish'),
  'sotuvchi': PositionInfo('Sotuvchi', Icons.shopping_cart_rounded, 'Savdo va mijozlar'),
  'ornatuvchi': PositionInfo('O\'rnatuvchi', Icons.build_rounded, 'Montaj va o\'rnatish'),
  'dizayner': PositionInfo('Dizayner', Icons.palette_rounded, 'Loyiha va dizayn'),
  'omborchi': PositionInfo('Omborchi', Icons.inventory_2_rounded, 'Ombor va materiallar'),
  'haydovchi': PositionInfo('Yetkazib beruvchi', Icons.local_shipping_rounded, 'Yetkazib berish'),
  'menejer': PositionInfo('Menejer', Icons.assignment_rounded, 'Boshqaruv'),
};

PositionInfo positionInfo(String key) =>
    kPositions[key] ?? PositionInfo(key, Icons.badge_rounded, '');
