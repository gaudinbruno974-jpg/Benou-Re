// Thème sombre teal/or, repris de l'identité visuelle web (LoginScreen/Parvis).
import 'package:flutter/material.dart';

class BrColors {
  static const background = Color(0xFF081619);
  static const backgroundDark = Color(0xFF040D10);
  static const surface = Color(0xFF122428);
  static const gold = Color(0xFFC5A059);
  static const goldBright = Color(0xFFE0B96A);
  static const teal = Color(0xFF0C7A7A);
  static const muted = Color(0xFF87A0A0);
  static const text = Color(0xFFE8E8E8);
}

ThemeData buildBrTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: BrColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: BrColors.teal,
      secondary: BrColors.gold,
      surface: BrColors.surface,
      onSurface: BrColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BrColors.surface,
      foregroundColor: BrColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: BrColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: BrColors.gold.withValues(alpha: 0.15)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrColors.backgroundDark.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: BrColors.muted.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: BrColors.muted.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrColors.gold),
      ),
      labelStyle: const TextStyle(color: BrColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrColors.teal,
        foregroundColor: BrColors.text,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}
