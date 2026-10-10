import 'package:flutter/material.dart';

/// Vida Market dizayn tokenlari — "Forest + Lime" (web `index.css` bilan bir xil).
/// Ranglar FAQAT shu yerda aniqlanadi; ekranlarda `AppColors.*` (semantik
/// nomlar) ishlatiladi, qattiq yozilgan hex qiymatlar emas.
class AppColors {
  // Fonlar
  static const background = Color(0xFFEEECE6); // sahifa foni (issiq greige)
  static const backgroundAlt = Color(0xFFF2F1EC); // surface-muted
  static const card = Color(0xFFFFFFFF);

  // Brend — "Forest + Lime"
  static const brand = Color(0xFF1D3A2F); // asosiy: to'q o'rmon yashili
  static const brandPressed = Color(0xFF2A5142);
  static const brandSecondary = Color(0xFF5E6A62);
  static const accent = Color(0xFFD4F06B); // lime: FAQAT to'ldirish (fill)
  static const onAccent = Color(0xFF1D3A2F); // lime ustidagi matn
  static const accentPressed = Color(0xFFC6E555);
  static const star = Color(0xFFD9A21B); // reyting yulduzchasi

  // Matn
  static const textPrimary = Color(0xFF1D3A2F);
  static const textSecondary = Color(0xFF5E6A62);
  static const textDisabled = Color(0xFF9AA39D);
  static const onBrand = Color(0xFFD4F06B); // brend rangi ustidagi matn/ikonka

  // Chegara va ajratgichlar
  static const border = Color(0xFFDCDAD2);
  static const disabledBackground = Color(0xFFE6E4DC);

  // Holatlar
  static const success = Color(0xFF2F7D4F);
  static const warning = Color(0xFFB9801F);
  static const error = Color(0xFFC2412D);
  static const info = Color(0xFF3979B7);
  static const errorSurface = Color(0xFFFBECE8); // xato bloki foni
  static const errorBorder = Color(0xFFF0C4BA);
  static const errorDark = Color(0xFF8A2E1F); // xato matni (quyuq)

  // --- Eski nomlar (mavjud ekranlar buzilmasligi uchun; yangi kodda ishlatmang) ---
  /// Brend rangi ustidagi och rang (tugma matni, belgi) — avval "cream".
  static const primary = onBrand;
  static const deep = brand;
  static const secondary = brandSecondary;
  static const surface = background;
  static const cardBorder = border;
}

/// 4 px asosli oraliq shkalasi.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0; // ekran chetlari
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Yagona burchak radiuslari.
class AppRadius {
  static const sm = 10.0;
  static const md = 14.0; // tugma, input
  static const lg = 18.0; // karta
  static const pill = 999.0;
}

/// Standart matn uslublari (rang `ThemeData.textTheme` orqali beriladi).
class AppText {
  static const pageTitle =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2);
  static const sectionTitle =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.25);
  static const productName =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25);
  static const price = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.brand);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const caption =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const body = TextStyle(fontSize: 14, height: 1.4);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.brandSecondary,
      tertiary: AppColors.accent,
      onTertiary: AppColors.onAccent,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
      outline: AppColors.border,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    dividerTheme:
        const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.textDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.textDisabled,
        elevation: 0,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(
            AppColors.brandPressed.withValues(alpha: 0.25)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        disabledBackgroundColor: AppColors.disabledBackground,
        disabledForegroundColor: AppColors.textDisabled,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.brand,
      // `color` aniq berilmasa, ba'zi Android qurilmalarida chip yorlig'i
      // deyarli oq/ko'rinmas rangda render bo'lib qolishi mumkin edi
      // (masalan bosh sahifadagi viloyat/GPS chip'i) — shu uchun aniq
      // rang belgilanadi.
      labelStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      secondaryLabelStyle: const TextStyle(
        color: AppColors.onBrand,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    // Android'da ba'zi qurilmalarda `showModalBottomSheet` uchun aniq
    // `backgroundColor` berilmasa, standart sirt/matn ranglari mos
    // kelmay, varaq deyarli oq va matn ko'rinmas bo'lib qolishi mumkin —
    // shu uchun fon va matn/ikonka ranglari bu yerda aniq belgilanadi,
    // har bir `showModalBottomSheet` chaqiruvida qayta yozishning hojati yo'q.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      modalBackgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Color(0x66000000),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textPrimary,
      iconColor: AppColors.brand,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.brand,
      contentTextStyle: const TextStyle(color: AppColors.onBrand),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.brand),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.brand,
      unselectedItemColor: AppColors.textSecondary,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelStyle: TextStyle(fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
