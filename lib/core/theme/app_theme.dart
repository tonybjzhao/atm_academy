import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF07111E);
  static const Color surface = Color(0xFF0D1F33);
  static const Color cardBg = Color(0xFF112240);
  static const Color primary = Color(0xFF00E676);
  static const Color secondary = Color(0xFF00B0FF);
  static const Color warning = Color(0xFFFFAB00);
  static const Color danger = Color(0xFFFF1744);
  static const Color textPrimary = Color(0xFFE8F4F8);
  static const Color textSecondary = Color(0xFF7CA3BE);
  static const Color borderColor = Color(0xFF1E3A5F);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: danger,
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor, width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: textPrimary),
          bodyLarge: TextStyle(color: textPrimary, height: 1.6),
          bodyMedium: TextStyle(color: textSecondary, height: 1.5),
          labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
      );
}
