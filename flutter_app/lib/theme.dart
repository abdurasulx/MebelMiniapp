import 'package:flutter/material.dart';

/// Web (`frontend/src/index.css`) va iOS (`Theme.swift`) bilan bir xil brend
/// ranglari — light rejimda cream, dark rejimda jigarrang.
class AppColors {
  static const primary = Color(0xFFECC299); // cream
  static const deep = Color(0xFF4C2C24); // jigarrang
  static const secondary = Color(0xFF3498DB);
  static const surface = Color(0xFFFBF4EC); // fon — iliq oq
  static const cardBorder = Color(0xFFE9DCC9);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.deep,
      primary: AppColors.deep,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.deep,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.deep,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.deep,
      displayColor: AppColors.deep,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.deep, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deep,
        foregroundColor: AppColors.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deep,
        side: const BorderSide(color: AppColors.cardBorder),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AppColors.deep,
      // `color` aniq berilmasa, ba'zi Android qurilmalarida chip yorlig'i
      // deyarli oq/ko'rinmas rangda render bo'lib qolishi mumkin edi
      // (masalan bosh sahifadagi viloyat/GPS chip'i) — shu uchun aniq
      // jigarrang rang belgilanadi.
      labelStyle: const TextStyle(
        color: AppColors.deep,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: const BorderSide(color: AppColors.cardBorder),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    // Android'da ba'zi qurilmalarda `showModalBottomSheet` uchun aniq
    // `backgroundColor` berilmasa, standart sirt/matn ranglari mos
    // kelmay, varaq deyarli oq va matn ko'rinmas bo'lib qolishi mumkin
    // (masalan bosh sahifadagi GPS/viloyat tanlash varag'i) — shu uchun
    // fon va matn/ikonka ranglari bu yerda aniq belgilanadi, har bir
    // `showModalBottomSheet` chaqiruvida alohida qayta yozishning hojati
    // yo'q.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      modalBackgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x66000000),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.deep,
      iconColor: AppColors.deep,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.deep,
      unselectedItemColor: Color(0xFFB8A48F),
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 11.5),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
