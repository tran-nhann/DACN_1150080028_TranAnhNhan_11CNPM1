import 'package:flutter/material.dart';

abstract final class AsterColors {
  static const ink = Color(0xFF172C3C);
  static const muted = Color(0xFF748591);
  static const teal = Color(0xFF087F75);
  static const dark = Color(0xFF123F43);
  static const background = Color(0xFFF3F7F5);
  static const border = Color(0xFFE5EBEF);
  static const amber = Color(0xFFAE7414);
  static const red = Color(0xFFB34F55);
}

ThemeData asterTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AsterColors.teal,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: AsterColors.teal,
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
        borderSide: const BorderSide(color: AsterColors.teal, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AsterColors.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
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
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: AsterColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      side: BorderSide(color: AsterColors.border),
      selectedColor: Color(0xFFE0F0EC),
      backgroundColor: Colors.white,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      indicatorColor: const Color(0xFFE0F0EC),
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AsterColors.teal
              : AsterColors.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AsterColors.dark,
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
