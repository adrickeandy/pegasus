import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0E0F11);
  static const Color surface = Color(0xFF1A1B1E);
  static const Color userBubble = Color(0xFF2B5CE6);
  static const Color modelBubble = Color(0xFF1F2023);
  static const Color errorBubble = Color(0xFF3A1C1C);
  static const Color textPrimary = Color(0xFFECECEC);
  static const Color textSecondary = Color(0xFF9A9CA3);
  static const Color accent = Color(0xFF6C8CFF);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15, height: 1.4),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
