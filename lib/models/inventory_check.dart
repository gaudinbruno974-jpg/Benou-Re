// Historique des vérifications de l'inventaire du matériel de Loge.
// Une vérification est autonome : elle n'est rattachée à aucune tenue.

const String kCheckConforme = 'Conforme';
const String kCheckManquant = 'Manquant';
const String kCheckEndommage = 'Endommagé';

const List<String> kInventoryCheckStatuses = [
  kCheckConforme,
  kCheckManquant,
  kCheckEndommage,
];

class InventoryCheckResult {
  final String status;
  final String comment;
  const InventoryCheckResult({
    this.status = kCheckConforme,
    this.comment = '',
  });

  factory InventoryCheckResult.fromMap(Map<String, dynamic> map) {
    return InventoryCheckResult(
      status: (map['status'] ?? kCheckConforme) as String,
      comment: (map['comment'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {'status': status, 'comment': comment};
}

class InventoryCheck {
  final String id;
  final String performedAt; // ISO datetime
  final String performedByName;
  final Map<String, InventoryCheckResult> results; // itemId -> résultat

  const InventoryCheck({
    required this.id,
    this.performedAt = '',
    this.performedByName = '',
    this.results = const {},
  });

  factory InventoryCheck.fromMap(String id, Map<String, dynamic> map) {
    final rawResults = (map['results'] as Map?) ?? {};
    return InventoryCheck(
      id: id,
      performedAt: (map['performedAt'] ?? '') as String,
      performedByName: (map['performedByName'] ?? '') as String,
      results: rawResults.map(
        (k, v) => MapEntry(
          k.toString(),
          InventoryCheckResult.fromMap(Map<String, dynamic>.from(v as Map)),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'performedAt': performedAt,
      'performedByName': performedByName,
      'results': results.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  DateTime? get dateTime => DateTime.tryParse(performedAt);

  int get countConforme =>
      results.values.where((r) => r.status == kCheckConforme).length;
  int get countManquant =>
      results.values.where((r) => r.status == kCheckManquant).length;
  int get countEndommage =>
      results.values.where((r) => r.status == kCheckEndommage).length;
}
