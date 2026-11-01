import 'package:flutter/material.dart';

abstract final class AsterColors {
  /// Chữ chính #1F2937 (Tiêu đề, số liệu)
  static const ink = Color(0xFF1F2937);

  /// Chữ phụ #6B7280 (Mô tả, nhãn)
  static const muted = Color(0xFF6B7280);

  /// Navy chủ đạo #0B2A56 (Thẻ lớn, header, nút chính)
  static const navy = Color(0xFF0B2A56);
  static const teal = Color(0xFF0B2A56);
  static const dark = Color(0xFF0B2A56);

  /// Navy phụ #123A7A (Chuyển màu, hover)
  static const navySecondary = Color(0xFF123A7A);

  /// Gold thương hiệu #D4AF37 (Vòng %, ngôi sao, điểm nhấn)
  static const gold = Color(0xFFD4AF37);
  static const amber = Color(0xFFD4AF37);

  /// Gold nhạt #F6E7B1 (Nền tab chọn, vùng nhấn nhẹ)
  static const goldLight = Color(0xFFF6E7B1);

  /// Nền ứng dụng #F8FAFC
  static const background = Color(0xFFF8FAFC);

  /// Viền thẻ #E2E8F0
  static const border = Color(0xFFE2E8F0);

  /// Cảnh báo / Hủy
  static const red = Color(0xFFDC2626);
}

ThemeData asterTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AsterColors.navy,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AsterColors.navy,
      secondary: AsterColors.gold,
      surface: Colors.white,
      onSurface: AsterColors.ink,
    ),
    scaffoldBackgroundColor: AsterColors.background,
    fontFamily: 'Manrope',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AsterColors.ink,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AsterColors.ink,
        letterSpacing: -.7,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AsterColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AsterColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: AsterColors.ink, height: 1.6),
      bodyMedium: TextStyle(
        fontSize: 13,
        color: AsterColors.muted,
        height: 1.6,
      ),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AsterColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AsterColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AsterColors.navy, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AsterColors.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AsterColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AsterColors.navy,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AsterColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AsterColors.navy,
        minimumSize: const Size(48, 48),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      side: BorderSide(color: AsterColors.border),
      selectedColor: AsterColors.goldLight,
      backgroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: AsterColors.goldLight,
      height: 74,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AsterColors.navy
              : AsterColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AsterColors.navy
              : AsterColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AsterColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      color: AsterColors.border,
      thickness: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AsterColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
