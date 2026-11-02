import 'package:flutter/material.dart';

/// Large, high-contrast, calm. Every tap target is at least 64 dp tall and
/// body text starts at 22 sp (roadmap: "Text is large, buttons are big,
/// contrast is high").
class AppColors {
  static const ink = Color(0xFF1A1A1A);
  static const paper = Color(0xFFFFFBF2);
  static const primary = Color(0xFF0B5D4B); // deep green
  static const primarySoft = Color(0xFFDDEFE8);
  static const accent = Color(0xFFB4530A); // terracotta
  static const accentSoft = Color(0xFFFBE7D6);
  static const highlight = Color(0xFFFFC928); // walkthrough glow
  static const callGreen = Color(0xFF1E7B34);
  static const muted = Color(0xFF555555);
  static const card = Colors.white;
  static const practice = Color(0xFF6A1B9A);
}

ThemeData buildTheme() {
  const base = TextTheme(
    displaySmall: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.35,
    ),
    headlineSmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    bodyLarge: TextStyle(fontSize: 22, height: 1.5),
    bodyMedium: TextStyle(fontSize: 20, height: 1.5),
    labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
  );
  final text = base.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 72,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        textStyle: text.labelLarge,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.ink, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: text.titleMedium,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: TextStyle(fontSize: 20),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
