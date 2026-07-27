// Modèle d'une tenue / session (porté depuis src/types.ts -> Session).

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

class Session {
  final String id;
  final String date; // ISO String
  final String degree; // 'Apprenti' | 'Compagnon' | 'Maitre'
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
  final String? driveFolderId;
  final String? driveFolderUrl;
  final num? chrono;

  // On conserve les autres champs bruts (planche, signatures d'officiers, etc.)
  // afin de ne perdre aucune donnée lors des lectures/écritures Firestore.
  final Map<String, dynamic> extra;

  const Session({
    required this.id,
    this.date = '',
    this.degree = 'Apprenti',
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
      degree: (map['degree'] ?? 'Apprenti') as String,
      type: (map['type'] ?? 'Ordinaire') as String,
      title: (map['title'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      dateReprise: map['dateReprise'] as String?,
      lieuReunion: map['lieuReunion'] as String?,
      presentIds: _stringList(map['presentIds']),
      excusedIds: _stringList(map['excusedIds']),
      visitorIds: _stringList(map['visitorIds']),
      troncAmount: (map['troncAmount'] ?? 0) as num,
      signatures: _stringMap(map['signatures']),
      closingTime: (map['closingTime'] ?? '18:30') as String,
      agenda1: (map['agenda1'] ?? '') as String,
      agenda2: (map['agenda2'] ?? '') as String,
      agenda3: (map['agenda3'] ?? '') as String,
      agenda4: (map['agenda4'] ?? '') as String,
      hasAgape: (map['hasAgape'] ?? false) as bool,
      agapeTime: (map['agapeTime'] ?? '20:00') as String,
      agapeType: (map['agapeType'] ?? 'Agape partage') as String,
      agapePrice: (map['agapePrice'] ?? 0) as num,
      sessionNumber: map['sessionNumber'] as String?,
      deityName: map['deityName'] as String?,
      egyptianYear: map['egyptianYear'] as String?,
      vmName: map['vmName'] as String?,
      customLines: _stringList(map['customLines']),
      plancheDraftText: map['plancheDraftText'] as String?,
      plancheValidated: (map['plancheValidated'] ?? false) as bool,
      isValidated: (map['isValidated'] ?? false) as bool,
      visitorRoles: _stringMap(map['visitorRoles']),
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
      'driveFolderId': driveFolderId,
      'driveFolderUrl': driveFolderUrl,
      'chrono': chrono,
      ...extra,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }

  DateTime? get dateTime {
    final raw = date.isNotEmpty ? date : (dateReprise ?? '');
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}
