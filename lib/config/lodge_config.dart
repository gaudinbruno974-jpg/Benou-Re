// Identité de la Loge : point de passage unique pour tout ce qui distingue une
// loge d'une autre (nom, orient, logos, dossiers Google Drive).
//
// Répartition retenue pour le multi-loges :
//   - ce qui doit être figé à la compilation (logos embarqués, applicationId,
//     `firebase_options.dart`) est porté par le *flavor*, via les valeurs par
//     défaut ci-dessous ;
//   - ce qui doit rester modifiable sans rebuild (nom, orient, lieu de
//     réunion, identifiants Drive) est relu depuis `config/settings` sur
//     Firestore et vient écraser ces valeurs au démarrage.
//
// Les valeurs par défaut sont celles du flavor actif (voir `forCurrentFlavor`
// ci-dessous) : sans réseau, ou pour un document généré hors connexion,
// l'application reste correcte.

import 'package:flutter/painting.dart' show Alignment, Color, LinearGradient;

import 'flavor.dart';

// Couleurs de marque par flavor, en constantes top-level : `theme.dart` les
// référence directement (Dart n'autorise pas l'accès à un champ d'instance,
// même `const`, dans une expression constante — donc pas de
// `LodgeConfig.benouRe.primaryColor` dans un contexte `const`). Ce sont ici
// les seules valeurs sources ; `LodgeConfig` les reprend telles quelles.
//
// Couvre TOUT ce qui donne son identité visuelle à une loge : accents
// (primary/accent) mais aussi fond, surface et dégradés (arrière-plan,
// cartes) — sans quoi seuls quelques détails changent et les deux loges se
// ressemblent malgré la palette.
const Color kBenouRePrimary = Color(0xFF16B6C7);
const Color kBenouReAccent = Color(0xFFD4B36A);
const Color kBenouReAccentBright = Color(0xFFEDCB82);
const Color kBenouReBackground = Color(0xFF123A52);
const Color kBenouReBackgroundDark = Color(0xFF0C2A3E);
const Color kBenouReSurface = Color(0xFF1C5570);
const LinearGradient kBenouReBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF15455F), Color(0xFF0F3349), Color(0xFF0A2334)],
  stops: [0.0, 0.55, 1.0],
);
const LinearGradient kBenouReCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF215F7C), Color(0xFF17475F)],
);

// Identité bleue : mêmes rôles, même structure de dégradé (3 paliers pour
// le fond, 2 pour les cartes) que Bénou Ré, teinte déplacée du bleu-turquoise
// vers un bleu roi/indigo — pas seulement les accents. Choisie distincte du
// cyan-turquoise de Bénou Ré (kBenouRePrimary) pour que les deux loges
// restent visuellement différenciables malgré une famille de couleur commune.
const Color kPetitPrincePrimary = Color(0xFF2E5FD9);
const Color kPetitPrinceAccent = Color(0xFF7FB2F0);
const Color kPetitPrinceAccentBright = Color(0xFFB3D4FA);
const Color kPetitPrinceBackground = Color(0xFF16294D);
const Color kPetitPrinceBackgroundDark = Color(0xFF0E1B36);
const Color kPetitPrinceSurface = Color(0xFF223A66);
const LinearGradient kPetitPrinceBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF1B2F5C), Color(0xFF15254A), Color(0xFF0C1830)],
  stops: [0.0, 0.55, 1.0],
);
const LinearGradient kPetitPrinceCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2A4A85), Color(0xFF1C3563)],
);

// Identité grise : même structure que les deux précédentes, teinte neutre
// (gris ardoise) plutôt que turquoise ou bleu. Un gris n'a pas de teinte
// pour « aider » le contraste comme le bleu ou le turquoise : la couleur
// primaire (fond de bouton, texte blanc dessus) reste volontairement assez
// sombre pour ne pas devenir terne/peu lisible, tandis que les accents
// (utilisés comme texte/bordures, pas comme fond) restent clairs.
const Color kTempleHorusPrimary = Color(0xFF64707D);
const Color kTempleHorusAccent = Color(0xFFC3CBD6);
const Color kTempleHorusAccentBright = Color(0xFFE2E7ED);
const Color kTempleHorusBackground = Color(0xFF2B2E33);
const Color kTempleHorusBackgroundDark = Color(0xFF1C1E22);
const Color kTempleHorusSurface = Color(0xFF3B3F45);
const LinearGradient kTempleHorusBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF34383E), Color(0xFF262931), Color(0xFF17191D)],
  stops: [0.0, 0.55, 1.0],
);
const LinearGradient kTempleHorusCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF454A52), Color(0xFF31353B)],
);

// Identité royale ivoire et or : première Loge de l'obédience, palette plus
// prestigieuse qu'un simple bronze — pourpre nuit profond (repris du dégradé
// violet/bleu déjà présent derrière l'étoile du sceau, voir
// assets/Al-Khemia.png) avec un or vif en primaire et un ivoire net en
// accent, pour un contraste marqué (le bronze/kaki initial manquait de
// contraste entre fond et cartes).
const Color kAlKhemiaPrimary = Color(0xFFD9A916);
const Color kAlKhemiaAccent = Color(0xFFF2E6C4);
const Color kAlKhemiaAccentBright = Color(0xFFF8F1DC);
const Color kAlKhemiaBackground = Color(0xFF1E1224);
const Color kAlKhemiaBackgroundDark = Color(0xFF130B17);
const Color kAlKhemiaSurface = Color(0xFF3A2842);
const LinearGradient kAlKhemiaBackgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2A1B32), Color(0xFF1E1224), Color(0xFF120A16)],
  stops: [0.0, 0.55, 1.0],
);
const LinearGradient kAlKhemiaCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF4A3350), Color(0xFF2E1F36)],
);

/// Rend une chaîne sans signes diacritiques (« Bénou Ré » → « Benou Re »).
///
/// Les documents officiels écrivent le nom de la Loge en capitales non
/// accentuées ; cette forme est dérivée du nom plutôt que ressaisie, pour
/// qu'une loge n'ait qu'une seule valeur à renseigner.
String withoutDiacritics(String value) {
  const from = 'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÑñÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝŸýÿ';
  const to = 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiNnOOOOOOooooooUUUUuuuuYYyy';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index == -1 ? char : to[index]);
  }
  return buffer.toString();
}

class LodgeConfig {
  /// Nom de la Loge, tel qu'il s'écrit (« Bénou Ré »).
  final String name;

  /// Numéro de la Loge au tableau de l'obédience, sans le « N° ».
  final String number;

  /// Orient, forme courte (« Saint-Pierre »).
  final String orient;

  /// Orient, forme développée pour l'en-tête des documents officiels.
  final String orientLong;

  /// Sigle de l'obédience : les noms complets sont trop longs pour la colonne
  /// « Loge » du PDF de paiement des agapes.
  final String obedienceAcronym;

  /// Lieu de réunion propose par défaut à la création d'une tenue.
  final String defaultMeetingPlace;

  /// Logo de l'obédience, embarqué dans les assets (en-tête des documents).
  final String obedienceLogoAsset;

  /// Logo de la Loge, embarqué dans les assets.
  final String lodgeLogoAsset;

  /// En-tête PDF (logos + titres GLDB / Loge) empilé en deux blocs distincts
  /// (un par logo) plutôt que les deux logos côte à côte dans la même
  /// rangée. Propriété d'identité visuelle figée au flavor, comme les logos
  /// et les couleurs : non modifiable depuis Firestore.
  final bool pdfHeaderStacked;

  /// Couleur principale de la loge (boutons, onglet actif, FAB).
  final Color primaryColor;

  /// Couleur d'accent de la loge (titres, bordures, badges).
  final Color accentColor;

  /// Variante plus claire de [accentColor] (libellés d'onglet, contours).
  final Color accentBrightColor;

  /// Couleur de fond principale (scaffold, dégradé le plus clair).
  final Color backgroundColor;

  /// Couleur de fond sombre (app bar, champs de saisie, superpositions).
  final Color backgroundDarkColor;

  /// Couleur des cartes, dialogues et surfaces (pavés).
  final Color surfaceColor;

  /// Dégradé peint derrière tous les écrans (voir `BrBackground`).
  final LinearGradient backgroundGradient;

  /// Dégradé des cartes contrastées (voir `BrCard`).
  final LinearGradient cardGradient;

  /// Origine du site web déployé de cette loge (sans slash final), utilisée
  /// pour construire les liens de réponse individuels envoyés hors
  /// application (§ 2 du cahier des charges Invitations) : ce lien doit
  /// rester correct même généré depuis l'app mobile, où `Uri.base` ne reflète
  /// pas l'hébergement web.
  final String webOrigin;

  /// Nom de l'association loi 1901 de la Loge, pour l'en-tête des documents
  /// de Trésorerie (Appel de cotisation, Quitus).
  final String treasuryAssociationName;

  /// Coordonnées bancaires de la Loge (RIB/IBAN), affichées sur l'Appel de
  /// cotisation. Saisie libre multi-lignes (le format d'un RIB varie).
  final String treasuryRib;

  /// Dossier Drive parent sous lequel sont créés les sous-dossiers annuels
  /// « Capitations {année} » / « Quitus {année} » (voir drive_service.dart).
  final String treasuryDriveFolderId;

  /// Dossier Drive dans lequel sont archivés les Passeports Maçonniques
  /// (un fichier par membre, voir drive_service.dart).
  final String passportDriveFolderId;

  /// Dossier Drive dans lequel sont archivés les cartons d'invitation des
  /// Tenues extérieures reçues (voir drive_service.dart).
  final String tenuesExterieuresDriveFolderId;

  /// Dossier Drive dans lequel sont archivées les Demandes (Suggestions /
  /// Dysfonctionnements) déposées par le V∴M∴ ou le Secrétaire, un PDF par
  /// demande (voir drive_service.dart).
  final String requestsDriveFolderId;

  /// Dossier Drive (accès V∴M∴ uniquement) dans lequel sont archivés le
  /// Rapport pour la Grande Loge et les exports de la page Statistiques
  /// (voir drive_service.dart).
  final String activityReportsDriveFolderId;

  /// Dossier Drive « 03 Dossier Membres » dans lequel est archivé le
  /// classeur Répertoires (Membres/Visiteurs/Dignitaires) — un seul fichier
  /// à la fois, voir [DriveService.archiveDirectoryDocument].
  final String membersDriveFolderId;

  /// Dossier Drive parent sous lequel sont créés les dossiers de tenue.
  final String driveParentFolderId;

  /// Dossiers Drive de la bibliothèque, par type de document puis par grade.
  /// Exemple : `{'Rituels': {'Apprenti': '1HUM…'}}`.
  final Map<String, Map<String, String>> libraryFolders;

  const LodgeConfig({
    required this.name,
    required this.number,
    required this.orient,
    required this.orientLong,
    required this.obedienceAcronym,
    required this.defaultMeetingPlace,
    required this.obedienceLogoAsset,
    required this.lodgeLogoAsset,
    this.pdfHeaderStacked = false,
    required this.primaryColor,
    required this.accentColor,
    required this.accentBrightColor,
    required this.backgroundColor,
    required this.backgroundDarkColor,
    required this.surfaceColor,
    required this.backgroundGradient,
    required this.cardGradient,
    required this.webOrigin,
    this.treasuryAssociationName = '',
    this.treasuryRib = '',
    this.treasuryDriveFolderId = '',
    this.passportDriveFolderId = '',
    this.tenuesExterieuresDriveFolderId = '',
    this.requestsDriveFolderId = '',
    this.activityReportsDriveFolderId = '',
    this.membersDriveFolderId = '',
    required this.driveParentFolderId,
    required this.libraryFolders,
  });

  /// Nom en capitales non accentuées, tel qu'il figure sur la planche tracée.
  String get nameUpperAscii => withoutDiacritics(name).toUpperCase();

  /// « R∴ L∴ Bénou Ré N°5 » — en-tête des documents officiels.
  String get shortTitle => 'R∴ L∴ $name N°$number';

  /// « Respectable Loge BENOU RE N°5 » — corps de la planche tracée.
  String get formalTitleUpper => 'Respectable Loge $nameUpperAscii N°$number';

  /// Valeurs de repli, propres au flavor Bénou Ré.
  static const LodgeConfig benouRe = LodgeConfig(
    name: 'Bénou Ré',
    number: '5',
    orient: 'Saint-Pierre',
    orientLong: 'Saint Pierre – Île de la Réunion',
    obedienceAcronym: 'GLDB',
    defaultMeetingPlace: 'Temple Thérèse Eliseman à Saint-Pierre',
    obedienceLogoAsset: 'assets/GLDB.png',
    lodgeLogoAsset: 'assets/Benou-Re.png',
    primaryColor: kBenouRePrimary,
    accentColor: kBenouReAccent,
    accentBrightColor: kBenouReAccentBright,
    backgroundColor: kBenouReBackground,
    backgroundDarkColor: kBenouReBackgroundDark,
    surfaceColor: kBenouReSurface,
    backgroundGradient: kBenouReBackgroundGradient,
    cardGradient: kBenouReCardGradient,
    webOrigin: 'https://benou-re-loge.web.app',
    driveParentFolderId: '11Qp8SXLFG0Spfks-G6OAQ66EHMGjEOgy',
    libraryFolders: {
      'Architecture': {
        'Apprenti': '16o7qUPDk31feVoX97NIB-JQezxGn9weV',
        'Compagnon': '1EyL-gwEMrGy1vIMAWpd9narrne4yQEvZ',
        'Maître': '11ez4G3OmCVWNT1BbMDgHfcFYfbKgeqDS',
      },
      'Rituels': {
        'Apprenti': '1HUMlA7LU4p2H2q2irhzR0d9ZbrW0sqhR',
        'Compagnon': '1uwoZMDaD6tUp3FkTQAKwXlpEy7H2ETwy',
        'Maître': '1VpvHOaxFNWbkeQHRCvr_pQI-iTSKe3_6',
      },
      'Instructions': {
        'Apprenti': '1qoK7fndJePm3DOxXeElXOowB8oPQB2v9',
        'Compagnon': '1n4fmiq36nQMu965bvKlpC5fiytQ_44oU',
        'Maître': '1J_DvRYyy39Myz2t_IYq7Xi516PyUETTi',
      },
    },
  );

  /// Valeurs de repli, propres au flavor Le Petit Prince.
  static const LodgeConfig petitPrince = LodgeConfig(
    name: 'Le Petit Prince',
    number: '2',
    orient: 'Saint-Pierre',
    orientLong: 'Saint Pierre – Île de la Réunion',
    obedienceAcronym: 'GLDB',
    defaultMeetingPlace: 'Temple Thérèse Eliseman à Saint-Pierre',
    obedienceLogoAsset: 'assets/GLDB.png',
    lodgeLogoAsset: 'assets/Petit-Prince.png',
    pdfHeaderStacked: true,
    primaryColor: kPetitPrincePrimary,
    accentColor: kPetitPrinceAccent,
    accentBrightColor: kPetitPrinceAccentBright,
    backgroundColor: kPetitPrinceBackground,
    backgroundDarkColor: kPetitPrinceBackgroundDark,
    surfaceColor: kPetitPrinceSurface,
    backgroundGradient: kPetitPrinceBackgroundGradient,
    cardGradient: kPetitPrinceCardGradient,
    webOrigin: 'https://petit-prince-loge.web.app',
    driveParentFolderId: '13JPdAvGz_dHCYGHs-9JrjpvvbnqgW_U5',
    libraryFolders: {
      'Architecture': {
        'Apprenti': '1IOmDYov8Cl1hnet-Q-QdNJiKjFqQCu4S',
        'Compagnon': '1aQv_5mu7h_cMvgTM7UDEXn6Ls_26CtSD',
        'Maître': '1pKt7t6wGW3vlZrZ-w_WhfZb87oRZWMu3',
      },
      'Instructions': {
        'Apprenti': '1ZF5zO2IR26vGBLGgB5qH8EX6bx7yBbIt',
        'Compagnon': '1aYorZAUdlMOs_WgiDgcXVVtWOS3mjYTZ',
        'Maître': '1vQBEKSzEDPbyYGMBpOTwJPvm8dcFr8U3',
      },
      'Rituels': {
        'Apprenti': '1QGq_I0s86rQKGy-9GmzFhgJ9IM_mPwp5',
        'Compagnon': '1feY3fYdzsY5lGwHA71YFMkAV8d3327nW',
        'Maître': '16qQDL4HrSgYOadjI8BHU8lQaewyOfylS',
      },
    },
  );

  /// Valeurs de repli, propres au flavor Le Temple d'Horus.
  ///
  /// Logo et dossiers Drive encore à compléter (voir suivi du déploiement) :
  /// [lodgeLogoAsset] pointe vers un fichier pas encore ajouté aux assets —
  /// sans conséquence tant qu'il n'est pas déclaré dans `pubspec.yaml`
  /// (`imageFromAssetBundle` échoue alors silencieusement, cf.
  /// `pdf_service.dart`). [driveParentFolderId] et [libraryFolders] restent
  /// vides tant qu'aucun dossier Drive n'a été créé pour cette loge.
  static const LodgeConfig templeHorus = LodgeConfig(
    name: "Le Temple d'Horus",
    number: '4',
    orient: 'Saint-Pierre',
    orientLong: 'Saint Pierre – Île de la Réunion',
    obedienceAcronym: 'GLDB',
    defaultMeetingPlace: 'Temple Thérèse Eliseman à Saint-Pierre',
    obedienceLogoAsset: 'assets/GLDB.png',
    lodgeLogoAsset: 'assets/Temple-Horus.png',
    pdfHeaderStacked: true,
    primaryColor: kTempleHorusPrimary,
    accentColor: kTempleHorusAccent,
    accentBrightColor: kTempleHorusAccentBright,
    backgroundColor: kTempleHorusBackground,
    backgroundDarkColor: kTempleHorusBackgroundDark,
    surfaceColor: kTempleHorusSurface,
    backgroundGradient: kTempleHorusBackgroundGradient,
    cardGradient: kTempleHorusCardGradient,
    webOrigin: 'https://temple-horus-loge.web.app',
    driveParentFolderId: '',
    libraryFolders: {},
  );

  /// Valeurs de repli, propres au flavor AL-KHEMIA.
  ///
  /// Dossiers Drive encore à compléter (voir suivi du déploiement) :
  /// [driveParentFolderId] et [libraryFolders] restent vides tant qu'aucun
  /// dossier Drive n'a été créé pour cette loge. [webOrigin] suppose l'id de
  /// projet Firebase `al-khemia-loge` — à corriger si l'id réel diffère.
  static const LodgeConfig alKhemia = LodgeConfig(
    name: 'AL-KHEMIA',
    number: '1',
    orient: 'Saint-Pierre',
    orientLong: 'Saint Pierre – Île de la Réunion',
    obedienceAcronym: 'GLDB',
    defaultMeetingPlace: 'Temple Thérèse Eliseman à Saint-Pierre',
    obedienceLogoAsset: 'assets/GLDB.png',
    lodgeLogoAsset: 'assets/Al-Khemia.png',
    pdfHeaderStacked: true,
    primaryColor: kAlKhemiaPrimary,
    accentColor: kAlKhemiaAccent,
    accentBrightColor: kAlKhemiaAccentBright,
    backgroundColor: kAlKhemiaBackground,
    backgroundDarkColor: kAlKhemiaBackgroundDark,
    surfaceColor: kAlKhemiaSurface,
    backgroundGradient: kAlKhemiaBackgroundGradient,
    cardGradient: kAlKhemiaCardGradient,
    webOrigin: 'https://al-khemia-loge.web.app',
    driveParentFolderId: '',
    libraryFolders: {},
  );

  /// Repli propre au flavor actif (voir `lib/config/flavor.dart`).
  static LodgeConfig get forCurrentFlavor {
    if (currentFlavor == 'petitprince') return petitPrince;
    if (currentFlavor == 'templehorus') return templeHorus;
    if (currentFlavor == 'alkhemia') return alKhemia;
    return benouRe;
  }

  /// Configuration active. Alimentée au démarrage par [AppState] à partir de
  /// `config/settings` ; vaut le repli du flavor tant que Firestore n'a rien
  /// renvoyé, ce qui couvre aussi les tests et la génération hors ligne.
  static LodgeConfig current = forCurrentFlavor;

  /// Applique les champs présents dans `config/settings`, en conservant la
  /// valeur du flavor pour ceux que le document ne porte pas : une loge n'a à
  /// renseigner que ce qui la distingue.
  LodgeConfig mergedWith(Map<String, dynamic> data) {
    String text(String key, String fallback) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) return fallback;
      return value.trim();
    }

    return LodgeConfig(
      name: text('lodgeName', name),
      number: text('lodgeNumber', number),
      orient: text('lodgeOrient', orient),
      orientLong: text('lodgeOrientLong', orientLong),
      obedienceAcronym: text('lodgeObedience', obedienceAcronym),
      defaultMeetingPlace: text('lodgeMeetingPlace', defaultMeetingPlace),
      // Les logos et les couleurs sont embarqués dans le binaire : ils
      // relèvent du flavor et ne peuvent pas être redéfinis à distance.
      obedienceLogoAsset: obedienceLogoAsset,
      lodgeLogoAsset: lodgeLogoAsset,
      pdfHeaderStacked: pdfHeaderStacked,
      primaryColor: primaryColor,
      accentColor: accentColor,
      accentBrightColor: accentBrightColor,
      backgroundColor: backgroundColor,
      backgroundDarkColor: backgroundDarkColor,
      surfaceColor: surfaceColor,
      backgroundGradient: backgroundGradient,
      cardGradient: cardGradient,
      webOrigin: webOrigin,
      treasuryAssociationName: text(
        'treasuryAssociationName',
        treasuryAssociationName,
      ),
      treasuryRib: text('treasuryRib', treasuryRib),
      treasuryDriveFolderId: text(
        'treasuryDriveFolderId',
        treasuryDriveFolderId,
      ),
      passportDriveFolderId: text(
        'passportDriveFolderId',
        passportDriveFolderId,
      ),
      tenuesExterieuresDriveFolderId: text(
        'tenuesExterieuresDriveFolderId',
        tenuesExterieuresDriveFolderId,
      ),
      requestsDriveFolderId: text(
        'requestsDriveFolderId',
        requestsDriveFolderId,
      ),
      activityReportsDriveFolderId: text(
        'activityReportsDriveFolderId',
        activityReportsDriveFolderId,
      ),
      membersDriveFolderId: text(
        'membersDriveFolderId',
        membersDriveFolderId,
      ),
      driveParentFolderId: text('driveParentFolderId', driveParentFolderId),
      libraryFolders: _mergedLibraryFolders(data['libraryFolders']),
    );
  }

  Map<String, Map<String, String>> _mergedLibraryFolders(Object? raw) {
    if (raw is! Map) return libraryFolders;
    final merged = {
      for (final entry in libraryFolders.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    for (final typeEntry in raw.entries) {
      final grades = typeEntry.value;
      if (grades is! Map) continue;
      final target = merged.putIfAbsent(
        typeEntry.key.toString(),
        () => <String, String>{},
      );
      for (final gradeEntry in grades.entries) {
        final id = gradeEntry.value;
        if (id is! String || id.trim().isEmpty) continue;
        target[gradeEntry.key.toString()] = id.trim();
      }
    }
    return merged;
  }
}
