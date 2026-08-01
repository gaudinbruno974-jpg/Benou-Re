import 'package:flutter/material.dart';

class BrColors {
  // ---- PALETTE TURQUOISE (plus bleue) ----
  static const background = Color(0xFF123A52);
  static const backgroundDark = Color(0xFF0C2A3E);
  static const surface = Color(0xFF1C5570);
  static const gold = Color(0xFFD4B36A);
  static const goldBright = Color(0xFFEDCB82);
  static const teal = Color(0xFF16B6C7);
  static const muted = Color(0xFFC4D8D8);
  static const text = Color(0xFFF8FAFA);

  // NOUVELLES CONSTANTES (pour les menus et erreurs)
  static const error = Color(0xFFFF8A80);
  static const divider = Color(0x40FFFFFF);
  static const menuArchitecture = Color(0xFF4FC3F7);
  static const menuInstruction = Color(0xFF9FA8DA);
  static const menuRituels = Color(0xFFCE93D8);
  static const menuTresorerie = Color(0xFFEF9A9A);
  static const menuVisiteurs = Color(0xFF81C784);

  // Couleur complémentaire du rite Memphis-Misraïm (accent de bordure).
  static const violet = Color(0xFF9B6FC9);
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
      error: BrColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BrColors.surface,
      foregroundColor: BrColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: BrColors.gold,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: BrColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: BrColors.violet.withValues(alpha: 0.35)),
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
        borderSide: BorderSide(color: BrColors.violet.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrColors.gold),
      ),
      labelStyle: const TextStyle(color: BrColors.muted),
      hintStyle: const TextStyle(color: BrColors.muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrColors.teal,
        foregroundColor: BrColors.text,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: BrColors.gold,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(color: BrColors.text),
    ),
  );
}
