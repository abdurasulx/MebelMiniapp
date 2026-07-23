import 'package:flutter/material.dart';

/// Web (`frontend/src/index.css`) va iOS (`Theme.swift`) bilan bir xil brend
/// ranglari — light rejimda cream, dark rejimda jigarrang.
class AppColors {
  static const primary = Color(0xFFECC299); // cream
  static const deep = Color(0xFF4C2C24); // jigarrang
  static const secondary = Color(0xFF3498DB);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.deep,
      primary: AppColors.deep,
      secondary: AppColors.secondary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.deep,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.deep,
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
