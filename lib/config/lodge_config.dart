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
// Les valeurs par défaut restent celles de Bénou Ré : sans réseau, ou pour un
// document généré hors connexion, l'application reste correcte.

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

  /// Configuration active. Alimentée au démarrage par [AppState] à partir de
  /// `config/settings` ; vaut le repli du flavor tant que Firestore n'a rien
  /// renvoyé, ce qui couvre aussi les tests et la génération hors ligne.
  static LodgeConfig current = benouRe;

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
      // Les logos sont embarqués dans le binaire : ils relèvent du flavor et ne
      // peuvent pas être redéfinis à distance.
      obedienceLogoAsset: obedienceLogoAsset,
      lodgeLogoAsset: lodgeLogoAsset,
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
