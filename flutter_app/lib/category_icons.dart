import 'package:flutter/material.dart';

/// Kategoriya -> ikonka (markaziy xarita). Backend'da kategoriya rasmi/ikonkasi
/// maydoni yo'q, shuning uchun nom/slug'dagi kalit so'zlar bo'yicha tanlanadi.
/// Hammasi bir xil "rounded" uslubda; noma'lum kategoriya uchun umumiy mebel
/// ikonkasi. Tartib muhim: aniqroq kalit so'zlar (kitob javoni) umumiyroqlaridan
/// (shkaf, stol) oldin turadi.
const _categoryIcons = <(List<String>, IconData)>[
  (['kitob', 'javon', 'polka', 'shelf'], Icons.shelves),
  (['divan', 'sofa', 'yumshoq', 'mehmon', 'zal'], Icons.weekend_rounded),
  (['karavat', 'krovat', 'yotoq', 'bed', 'matras'], Icons.bed_rounded),
  (['shkaf', 'garderob', 'jovon', 'komod'], Icons.door_sliding_rounded),
  (['stol', 'table', 'jurnal'], Icons.table_restaurant_rounded),
  (['oshxona', 'kuxn', 'kitchen'], Icons.kitchen_rounded),
  (['bolalar', 'bola', 'kids', 'child'], Icons.child_care_rounded),
  (['bog', 'tashqi', 'garden', 'outdoor'], Icons.deck_rounded),
  (['ofis', 'office'], Icons.desk_rounded),
  (['yoritgich', 'chiroq', 'lamp'], Icons.light_rounded),
  (['kreslo', 'stul', 'chair'], Icons.chair_alt_rounded),
];

IconData categoryIcon({required String slug, required String name}) {
  final key = '$slug $name'.toLowerCase();
  for (final (words, icon) in _categoryIcons) {
    if (words.any(key.contains)) return icon;
  }
  return Icons.chair_rounded;
}
