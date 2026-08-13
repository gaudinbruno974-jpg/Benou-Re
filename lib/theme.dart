import 'package:flutter/material.dart';

import 'config/flavor.dart';
import 'config/lodge_config.dart';

class BrColors {
  // Couleurs de marque : propres au flavor actif (voir LodgeConfig). TOUTES
  // les couleurs qui donnent son identité visuelle à une loge (accents, fond,
  // surface, dégradés de fond et de cartes) varient ici — pas seulement
  // l'accent doré. `currentFlavor` est une constante de compilation
  // (lib/config/flavor.dart), donc ces valeurs restent `const` — tous les
  // widgets `const` qui les utilisent ailleurs dans l'app continuent de
  // compiler sans modification.
  static const gold = currentFlavor == 'petitprince'
      ? kPetitPrinceAccent
      : kBenouReAccent;
  static const goldBright = currentFlavor == 'petitprince'
      ? kPetitPrinceAccentBright
      : kBenouReAccentBright;
  static const teal = currentFlavor == 'petitprince'
      ? kPetitPrincePrimary
      : kBenouRePrimary;
  static const background = currentFlavor == 'petitprince'
      ? kPetitPrinceBackground
      : kBenouReBackground;
  static const backgroundDark = currentFlavor == 'petitprince'
      ? kPetitPrinceBackgroundDark
      : kBenouReBackgroundDark;
  static const surface = currentFlavor == 'petitprince'
      ? kPetitPrinceSurface
      : kBenouReSurface;
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

  // ---- ESTHÉTIQUE : dégradés, ombres, rayons ----
  /// Dégradé de fond principal, peint derrière tous les écrans (voir
  /// `BrBackground`) : turquoise profond pour Bénou Ré, violet nuit pour Le
  /// Petit Prince.
  static const backgroundGradient = currentFlavor == 'petitprince'
      ? kPetitPrinceBackgroundGradient
      : kBenouReBackgroundGradient;

  /// Dégradé utilisé pour les cartes contrastées (voir `BrCard`).
  static const cardGradient = currentFlavor == 'petitprince'
      ? kPetitPrinceCardGradient
      : kBenouReCardGradient;

  /// Dégradé doré (accents, titres, boutons mis en valeur).
  static const goldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gold, goldBright],
  );

  static const radiusS = 12.0;
  static const radiusM = 18.0;
  static const radiusL = 24.0;

  /// Ombre douce réutilisable pour les cartes et conteneurs.
  static List<BoxShadow> get softShadow => const [
    BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Ombre plus marquée pour les éléments mis en avant.
  static List<BoxShadow> get raisedShadow => const [
    BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Bordure dorée subtile des cartes.
  static Border get subtleGoldBorder =>
      Border.fromBorderSide(BorderSide(color: gold.withValues(alpha: 0.22)));

  /// Couleur d'accent associée à un grade maçonnique.
  static Color forGrade(String grade) {
    final g = grade.toLowerCase();
    if (g.contains('apprenti')) return menuArchitecture;
    if (g.contains('compagnon')) return menuVisiteurs;
    if (g.contains('maître') || g.contains('maitre')) return gold;
    return violet;
  }

  /// Couleur d'avatar dérivée d'un texte (initiales colorées stables).
  static Color forSeed(String seed) {
    const palette = [
      teal,
      gold,
      violet,
      menuArchitecture,
      menuInstruction,
      menuRituels,
      menuVisiteurs,
      menuTresorerie,
    ];
    if (seed.isEmpty) return teal;
    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}

ThemeData buildBrTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    // Fond principal : couleur uniforme (le dégradé est optionnel en arrière
    // plan, mais les tests et certaines vues s'appuient sur une couleur fixe).
    scaffoldBackgroundColor: BrColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: BrColors.teal,
      secondary: BrColors.gold,
      surface: BrColors.surface,
      onSurface: BrColors.text,
      error: BrColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BrColors.backgroundDark.withValues(alpha: 0.55),
      surfaceTintColor: Colors.transparent,
      foregroundColor: BrColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: BrColors.gold,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: BrColors.surface.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x66000000),
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusM),
        side: BorderSide(color: BrColors.gold.withValues(alpha: 0.2)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BrColors.divider,
      thickness: 1,
      space: 24,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: BrColors.gold,
      textColor: BrColors.text,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusM),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: BrColors.backgroundDark.withValues(alpha: 0.5),
      side: BorderSide(color: BrColors.gold.withValues(alpha: 0.25)),
      labelStyle: const TextStyle(color: BrColors.text, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: BrColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusL),
        side: BorderSide(color: BrColors.gold.withValues(alpha: 0.25)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: BrColors.goldBright,
      unselectedLabelColor: BrColors.muted,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: BrColors.teal.withValues(alpha: 0.18),
        border: Border.all(color: BrColors.gold.withValues(alpha: 0.35)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BrColors.surface,
      contentTextStyle: const TextStyle(color: BrColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusS),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrColors.backgroundDark.withValues(alpha: 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusS),
        borderSide: BorderSide(color: BrColors.muted.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusS),
        borderSide: BorderSide(color: BrColors.gold.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrColors.radiusS),
        borderSide: const BorderSide(color: BrColors.gold, width: 1.6),
      ),
      labelStyle: const TextStyle(color: BrColors.muted),
      hintStyle: TextStyle(color: BrColors.muted.withValues(alpha: 0.7)),
      floatingLabelStyle: const TextStyle(color: BrColors.goldBright),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrColors.teal,
        foregroundColor: BrColors.text,
        elevation: 4,
        shadowColor: const Color(0x66000000),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrColors.radiusS),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrColors.goldBright,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        side: BorderSide(color: BrColors.gold.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrColors.radiusS),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: BrColors.goldBright),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BrColors.teal,
      foregroundColor: BrColors.text,
      elevation: 6,
    ),
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: BrColors.gold,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: BrColors.text,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(color: BrColors.text),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: BrColors.text,
        height: 1.35,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(color: BrColors.muted),
    ),
  );
}
