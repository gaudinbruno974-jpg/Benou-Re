// Tenue d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) — structure très
// différente d'une tenue de loge bleue (voir models/session.dart) : l'ordre
// du jour y est presque entièrement figé (voir hg_pdf_service.dart), seuls
// quelques champs varient d'une tenue à l'autre. Présences / émargement /
// planche tracée en revanche suivent le même principe que les loges bleues
// (voir grande_loge_hg_presence_screen.dart etc.), simplifié à un seul
// signataire de planche (le Trois Fois Puissant Maître) : un Collège de
// Perfection n'a pas les offices Orateur/V∴M∴/Secrétaire distincts d'une
// loge bleue.
List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return <String>[];
}

Map<String, String> _stringMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val?.toString() ?? ''));
  }
  return <String, String>{};
}

class HgSession {
  final String id;
  final String date; // ISO String
  final String heure; // « 19H30 »
  final int degree; // 4 à 14 pour IAH-MES
  final String lieu;
  final String themeTitle;
  final String themeText;
  final num agapePrice;

  /// Nom du signataire (« Trois Fois Puissant Maître » pour IAH-MES) — champ
  /// libre plutôt que déduit d'un compte : la personne qui tient ce rôle
  /// peut changer sans qu'on ait à retoucher le code.
  final String signerName;

  // ─── Présences ──────────────────────────────────────────────────────
  final List<String> presentIds;
  final List<String> excusedIds;
  final List<String> agapeIds;
  final List<String> visitorIds;
  final Map<String, String> visitorRoles;
  final List<String> visitorAgapeIds;
  final List<String> dignitaryIds;
  final Map<String, String> dignitaryRoles;
  final List<String> dignitaryAgapeIds;

  // ─── Émargement (id présent -> signature data URL) ─────────────────
  final Map<String, String> signatures;

  /// Signature du Trois Fois Puissant Maître sur la planche tracée — un
  /// seul signataire, contrairement aux 3 de la planche d'une loge bleue.
  final String? signerSignature;

  // ─── Planche tracée (compte-rendu du travail collectif) ────────────
  final String plancheText;
  final bool plancheValidated;

  const HgSession({
    required this.id,
    this.date = '',
    this.heure = '19H30',
    this.degree = 4,
    this.lieu = '',
    this.themeTitle = '',
    this.themeText = '',
    this.agapePrice = 15,
    this.signerName = '',
    this.presentIds = const [],
    this.excusedIds = const [],
    this.agapeIds = const [],
    this.visitorIds = const [],
    this.visitorRoles = const {},
    this.visitorAgapeIds = const [],
    this.dignitaryIds = const [],
    this.dignitaryRoles = const {},
    this.dignitaryAgapeIds = const [],
    this.signatures = const {},
    this.signerSignature,
    this.plancheText = '',
    this.plancheValidated = false,
  });

  factory HgSession.fromMap(String id, Map<String, dynamic> map) {
    return HgSession(
      id: id,
      date: (map['date'] ?? '') as String,
      heure: (map['heure'] ?? '19H30') as String,
      degree: ((map['degree'] ?? 4) as num).toInt(),
      lieu: (map['lieu'] ?? '') as String,
      themeTitle: (map['themeTitle'] ?? '') as String,
      themeText: (map['themeText'] ?? '') as String,
      agapePrice: (map['agapePrice'] ?? 15) as num,
      signerName: (map['signerName'] ?? '') as String,
      presentIds: _stringList(map['presentIds']),
      excusedIds: _stringList(map['excusedIds']),
      agapeIds: _stringList(map['agapeIds']),
      visitorIds: _stringList(map['visitorIds']),
      visitorRoles: _stringMap(map['visitorRoles']),
      visitorAgapeIds: _stringList(map['visitorAgapeIds']),
      dignitaryIds: _stringList(map['dignitaryIds']),
      dignitaryRoles: _stringMap(map['dignitaryRoles']),
      dignitaryAgapeIds: _stringList(map['dignitaryAgapeIds']),
      signatures: _stringMap(map['signatures']),
      signerSignature: map['signerSignature'] as String?,
      plancheText: (map['plancheText'] ?? '') as String,
      plancheValidated: (map['plancheValidated'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'date': date,
      'heure': heure,
      'degree': degree,
      'lieu': lieu,
      'themeTitle': themeTitle,
      'themeText': themeText,
      'agapePrice': agapePrice,
      'signerName': signerName,
      'presentIds': presentIds,
      'excusedIds': excusedIds,
      'agapeIds': agapeIds,
      'visitorIds': visitorIds,
      'visitorRoles': visitorRoles,
      'visitorAgapeIds': visitorAgapeIds,
      'dignitaryIds': dignitaryIds,
      'dignitaryRoles': dignitaryRoles,
      'dignitaryAgapeIds': dignitaryAgapeIds,
      'signatures': signatures,
      'signerSignature': signerSignature,
      'plancheText': plancheText,
      'plancheValidated': plancheValidated,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }

  HgSession copyWith({
    List<String>? presentIds,
    List<String>? excusedIds,
    List<String>? agapeIds,
    List<String>? visitorIds,
    Map<String, String>? visitorRoles,
    List<String>? visitorAgapeIds,
    List<String>? dignitaryIds,
    Map<String, String>? dignitaryRoles,
    List<String>? dignitaryAgapeIds,
    Map<String, String>? signatures,
    String? signerSignature,
    String? plancheText,
    bool? plancheValidated,
  }) {
    return HgSession(
      id: id,
      date: date,
      heure: heure,
      degree: degree,
      lieu: lieu,
      themeTitle: themeTitle,
      themeText: themeText,
      agapePrice: agapePrice,
      signerName: signerName,
      presentIds: presentIds ?? this.presentIds,
      excusedIds: excusedIds ?? this.excusedIds,
      agapeIds: agapeIds ?? this.agapeIds,
      visitorIds: visitorIds ?? this.visitorIds,
      visitorRoles: visitorRoles ?? this.visitorRoles,
      visitorAgapeIds: visitorAgapeIds ?? this.visitorAgapeIds,
      dignitaryIds: dignitaryIds ?? this.dignitaryIds,
      dignitaryRoles: dignitaryRoles ?? this.dignitaryRoles,
      dignitaryAgapeIds: dignitaryAgapeIds ?? this.dignitaryAgapeIds,
      signatures: signatures ?? this.signatures,
      signerSignature: signerSignature ?? this.signerSignature,
      plancheText: plancheText ?? this.plancheText,
      plancheValidated: plancheValidated ?? this.plancheValidated,
    );
  }

  DateTime? get dateTime => DateTime.tryParse(date);
}

/// Nomenclature standard du Collège de Perfection (4°-14°), reprise par la
/// plupart des rites dont Memphis-Misraïm — confirmée par l'utilisateur pour
/// IAH-MES.
const Map<int, String> kIahMesDegreeNames = {
  4: 'Maître Secret',
  5: 'Maître Parfait',
  6: 'Secrétaire Intime',
  7: 'Prévôt et Juge',
  8: 'Intendant des Bâtiments',
  9: 'Maître Élu des Neuf',
  10: 'Illustre Élu des Quinze',
  11: 'Sublime Chevalier Élu',
  12: 'Grand Maître Architecte',
  13: 'Royale Arche',
  14: 'Grand Écossais de la Voûte Sacrée',
};
