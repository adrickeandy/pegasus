import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Deep gradient background — the glass panels float above this.
  static const Color bgTop = Color(0xFF0B0E1A);
  static const Color bgBottom = Color(0xFF12081F);

  static const Color glassFill = Color(0x33FFFFFF); // translucent white
  static const Color glassBorder = Color(0x33FFFFFF);

  static const Color userBubble = Color(0xCC3B5CFF); // translucent accent
  static const Color modelBubble = Color(0x1FFFFFFF);
  static const Color errorBubble = Color(0x33FF5C5C);

  static const Color textPrimary = Color(0xFFF2F2F7);
  static const Color textSecondary = Color(0xFFA9ACC0);
  static const Color accent = Color(0xFF7C93FF);
  static const Color accentGlow = Color(0xFF9B7CFF);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgTop, bgBottom],
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(primary: accent, surface: bgTop),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
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
        bodyLarge: TextStyle(color: textPrimary, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }
}
