// Modèle d'une tenue / session (porté depuis src/types.ts -> Session).
import 'agenda_item.dart';
import 'member.dart';

List<String> _stringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return <String>[];
}

/// Lecture tolérante d'un montant (num, String « 42 » / « 42,50 » ou absent).
num _num(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim().replaceAll(',', '.')) ?? 0;
  return 0;
}

Map<String, String> _stringMap(dynamic v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val?.toString() ?? ''));
  }
  return <String, String>{};
}

class Session {
  final String id;
  final String date; // ISO String
  final String degree; // kApprenti | kCompagnon | kMaitre
  final String type; // 'Ordinaire' | 'Solennelle' | ...
  final String title;
  final String description;
  final String location;
  final String? dateReprise;
  final String? lieuReunion;
  final List<String> presentIds;
  final List<String> excusedIds;
  final List<String> visitorIds;
  final num troncAmount;
  final Map<String, String> signatures; // id -> base64
  final String closingTime;
  final String agenda1;
  final String agenda2;
  final String agenda3;
  final String agenda4;
  final bool hasAgape;
  final String agapeTime;
  final String agapeType;
  final num agapePrice;
  final String? sessionNumber;
  final String? deityName;
  final String? egyptianYear;
  final String? vmName;
  final List<String> customLines;
  final String? plancheDraftText;
  final bool plancheValidated;
  final bool isValidated;
  final Map<String, String> visitorRoles;
  final List<String> dignitaryIds;
  final Map<String, String> dignitaryRoles;
  final String? driveFolderId;
  final String? driveFolderUrl;
  final num? chrono;

  // On conserve les autres champs bruts (planche, signatures d'officiers, etc.)
  // afin de ne perdre aucune donnée lors des lectures/écritures Firestore.
  final Map<String, dynamic> extra;

  const Session({
    required this.id,
    this.date = '',
    this.degree = kApprenti,
    this.type = 'Ordinaire',
    this.title = '',
    this.description = '',
    this.location = '',
    this.dateReprise,
    this.lieuReunion,
    this.presentIds = const [],
    this.excusedIds = const [],
    this.visitorIds = const [],
    this.troncAmount = 0,
    this.signatures = const {},
    this.closingTime = '18:30',
    this.agenda1 = '',
    this.agenda2 = '',
    this.agenda3 = '',
    this.agenda4 = '',
    this.hasAgape = false,
    this.agapeTime = '20:00',
    this.agapeType = 'Agape partage',
    this.agapePrice = 0,
    this.sessionNumber,
    this.deityName,
    this.egyptianYear,
    this.vmName,
    this.customLines = const [],
    this.plancheDraftText,
    this.plancheValidated = false,
    this.isValidated = false,
    this.visitorRoles = const {},
    this.dignitaryIds = const [],
    this.dignitaryRoles = const {},
    this.driveFolderId,
    this.driveFolderUrl,
    this.chrono,
    this.extra = const {},
  });

  static const Set<String> _knownKeys = {
    'id', 'date', 'degree', 'type', 'title', 'description', 'location',
    'dateReprise', 'lieuReunion', 'presentIds', 'excusedIds', 'visitorIds',
    'troncAmount', 'signatures', 'closingTime', 'agenda1', 'agenda2',
    'agenda3', 'agenda4', 'hasAgape', 'agapeTime', 'agapeType', 'agapePrice',
    'sessionNumber', 'deityName', 'egyptianYear', 'vmName', 'customLines',
    'plancheDraftText', 'plancheValidated', 'isValidated', 'visitorRoles',
    'dignitaryIds', 'dignitaryRoles',
    'driveFolderId', 'driveFolderUrl', 'chrono',
  };

  factory Session.fromMap(String id, Map<String, dynamic> map) {
    final extra = <String, dynamic>{};
    map.forEach((k, v) {
      if (!_knownKeys.contains(k)) extra[k] = v;
    });
    return Session(
      id: id,
      date: (map['date'] ?? '') as String,
      degree: normalizeGrade(map['degree'] as String?),
      type: (map['type'] ?? 'Ordinaire') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      dateReprise: map['dateReprise'] as String?,
      lieuReunion: map['lieuReunion'] as String?,
      presentIds: _stringList(map['presentIds']),
      excusedIds: _stringList(map['excusedIds']),
      visitorIds: _stringList(map['visitorIds']),
      troncAmount: _num(map['troncAmount']),
      signatures: _stringMap(map['signatures']),
      closingTime: (map['closingTime'] ?? '18:30') as String,
      agenda1: (map['agenda1'] ?? '') as String,
      agenda2: (map['agenda2'] ?? '') as String,
      agenda3: (map['agenda3'] ?? '') as String,
      agenda4: (map['agenda4'] ?? '') as String,
      hasAgape: (map['hasAgape'] ?? false) as bool,
      agapeTime: (map['agapeTime'] ?? '20:00') as String,
      agapeType: (map['agapeType'] ?? 'Agape partage') as String,
      agapePrice: _num(map['agapePrice']),
      sessionNumber: map['sessionNumber'] as String?,
      deityName: map['deityName'] as String?,
      egyptianYear: map['egyptianYear'] as String?,
      vmName: map['vmName'] as String?,
      customLines: _stringList(map['customLines']),
      plancheDraftText: map['plancheDraftText'] as String?,
      plancheValidated: (map['plancheValidated'] ?? false) as bool,
      isValidated: (map['isValidated'] ?? false) as bool,
      visitorRoles: _stringMap(map['visitorRoles']),
      dignitaryIds: _stringList(map['dignitaryIds']),
      dignitaryRoles: _stringMap(map['dignitaryRoles']),
      driveFolderId: map['driveFolderId'] as String?,
      driveFolderUrl: map['driveFolderUrl'] as String?,
      chrono: map['chrono'] as num?,
      extra: extra,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'date': date,
      'degree': degree,
      'type': type,
      'title': title,
      'description': description,
      'location': location,
      'dateReprise': dateReprise,
      'lieuReunion': lieuReunion,
      'presentIds': presentIds,
      'excusedIds': excusedIds,
      'visitorIds': visitorIds,
      'troncAmount': troncAmount,
      'signatures': signatures,
      'closingTime': closingTime,
      'agenda1': agenda1,
      'agenda2': agenda2,
      'agenda3': agenda3,
      'agenda4': agenda4,
      'hasAgape': hasAgape,
      'agapeTime': agapeTime,
      'agapeType': agapeType,
      'agapePrice': agapePrice,
      'sessionNumber': sessionNumber,
      'deityName': deityName,
      'egyptianYear': egyptianYear,
      'vmName': vmName,
      'customLines': customLines,
      'plancheDraftText': plancheDraftText,
      'plancheValidated': plancheValidated,
      'isValidated': isValidated,
      'visitorRoles': visitorRoles,
      'dignitaryIds': dignitaryIds,
      'dignitaryRoles': dignitaryRoles,
      'driveFolderId': driveFolderId,
      'driveFolderUrl': driveFolderUrl,
      'chrono': chrono,
      ...extra,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }

  DateTime? get dateTime {
    final reprise = dateReprise ?? '';
    final raw = reprise.isNotEmpty ? reprise : date;
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Tenue « suspendue » : sa date est antérieure au jour courant
  /// (onglet « Travaux Suspendus »).
  bool get isSuspended {
    final now = DateTime.now();
    return dateTime?.isBefore(DateTime(now.year, now.month, now.day)) == true;
  }

  // ─── Champs additionnels (stockés dans `extra`) utilisés par les PDF ──
  String? _s(String key) {
    final v = extra[key];
    return v is String ? v : null;
  }

  String? get travail1 => _s('travail1');
  String? get travail2 => _s('travail2');
  String? get travail3 => _s('travail3');
  String? get travail4 => _s('travail4');
  String? get ligneCloture => _s('ligneCloture');
  String? get typeTenue => _s('typeTenue');
  String? get degreTravail => _s('degreTravail');
  String? get lieuReunionExtra => lieuReunion ?? _s('lieuReunion');
  String? get plancheOrateurName => _s('plancheOrateurName');
  String? get sacPropositions => _s('sacPropositions');
  String? get plancheOrateurSignature => _s('plancheOrateurSignature');
  String? get plancheVMSignature => _s('plancheVMSignature');
  String? get plancheSecretarySignature => _s('plancheSecretarySignature');

  List<String> get ordresJour => _stringList(extra['ordresJour']);

  /// Version typée de [ordresJour] (point simple / planche avec auteur) —
  /// lit `extra['agendaItems']` si présent (tenues créées avec ce typage),
  /// sinon se rabat sur [ordresJour] en enveloppant chaque ligne en point
  /// simple sans auteur : une tenue déjà enregistrée avant ce typage compte
  /// donc simplement 0 planche identifiée, sans erreur ni migration.
  List<AgendaItem> get agendaItems {
    final raw = extra['agendaItems'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => AgendaItem.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    }
    return ordresJour.map((t) => AgendaItem(text: t)).toList();
  }
  List<String> get plancheTravauxNotes => _stringList(extra['plancheTravauxNotes']);

  /// Membres annoncés présents aux agapes (réponses au sondage WhatsApp).
  List<String> get agapeIds => _stringList(extra['agapeIds']);

  /// Visiteurs annoncés présents aux agapes.
  List<String> get visitorAgapeIds => _stringList(extra['visitorAgapeIds']);

  /// Dignitaires annoncés présents aux agapes.
  List<String> get dignitaryAgapeIds => _stringList(extra['dignitaryAgapeIds']);

  /// Signatures de paiement des agapes (data URL). Clé : id du membre ou du
  /// visiteur qui a payé sa médaille.
  Map<String, String> get agapePaymentSignatures =>
      _stringMap(extra['agapePaymentSignatures']);

  /// Commentaires ajoutés sous les lignes du texte de la planche tracée
  /// (Tenue suspendue). Clé : index de la ligne.
  Map<String, String> get plancheLineComments =>
      _stringMap(extra['plancheLineComments']);

  num? get montantMedaille {
    final v = extra['montantMedaille'];
    return v is num ? v : null;
  }

  // ─── Champs de planification (parité SessionsList.tsx) ────────────────
  String? get heureSuspension => _s('heureSuspension');
  String? get heureAgape => _s('heureAgape');
  String? get typeRepas => _s('typeRepas');
  String get statut => _s('status') ?? 'Planifiée';
  bool get suitAgapes => (extra['suitAgapes'] as bool?) ?? hasAgape;

  /// Type affiché : préfère le champ React `typeTenue`, sinon `type`.
  String get typeLabel =>
      (typeTenue != null && typeTenue!.isNotEmpty) ? typeTenue! : type;

  /// Degré affiché : préfère le champ React `degreTravail`, sinon `degree`.
  String get degreeLabel => (degreTravail != null && degreTravail!.isNotEmpty)
      ? normalizeGrade(degreTravail)
      : degree;

  /// Suffixe « jj mm aa X » (date de la tenue + initiale du grade) ajouté
  /// aux noms des PDF archivés sur Drive (Convocation, Émargement, Planche
  /// tracée, Paiement des Agapes) — ex. « 27 10 24 A » pour une tenue du
  /// 27/10/2024 au degré Apprenti. Vide si la date ou le grade manquent
  /// (tenue pas encore complète), plutôt qu'un texte incohérent.
  String get driveFileDateGradeSuffix {
    final dt = dateTime;
    final dateLabel = dt == null
        ? ''
        : '${dt.day.toString().padLeft(2, '0')} '
            '${dt.month.toString().padLeft(2, '0')} '
            '${(dt.year % 100).toString().padLeft(2, '0')}';
    final grade = normalizeGrade(degree);
    final gradeLetter = grade == kMaitre
        ? 'M'
        : grade == kCompagnon
            ? 'C'
            : grade == kApprenti
                ? 'A'
                : '';
    final parts = [
      if (dateLabel.isNotEmpty) dateLabel,
      if (gradeLetter.isNotEmpty) gradeLetter,
    ];
    return parts.isEmpty ? '' : ' ${parts.join(' ')}';
  }

  /// Nombre d'ordres du jour complémentaires non vides.
  int get ordresJourCount =>
      ordresJour.where((o) => o.trim().isNotEmpty).length;

  /// Ordinal du degré (1er / 2ème / 3ème).
  static String degreeOrdinal(String d) {
    switch (normalizeGrade(d)) {
      case kCompagnon:
        return '2ème';
      case kMaitre:
        return '3ème';
      default:
        return '1er';
    }
  }

  /// Rang hiérarchique du degré : Apprenti (1) < Compagnon (2) < Maître (3).
  static int degreeRank(String d) {
    switch (normalizeGrade(d)) {
      case kCompagnon:
        return 2;
      case kMaitre:
        return 3;
      default:
        return 1;
    }
  }
}
