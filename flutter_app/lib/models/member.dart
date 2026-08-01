// Modèle d'un membre de l'Atelier (porté depuis src/types.ts -> Member).

/// Droit d'édition des tenues : V∴M∴, Secrétaire ou administrateur.
/// Même critère que le web (`canEdit` dans PlancheTraceeScreen.tsx).
bool canEditSessions(Member? user) {
  if (user == null) return false;
  final fn = user.function.trim();
  return user.isAdmin ||
      fn.contains('Vénérable Maître') ||
      fn.contains('Secrétaire');
}

/// Cotisations d'un membre pour une année donnée.
class DuesYear {
  final num lodgeDues;
  final bool lodgeDuesPaid;
  final num orderDues;
  final bool orderDuesPaid;
  final num elevationDues;
  final bool elevationDuesPaid;

  const DuesYear({
    this.lodgeDues = 0,
    this.lodgeDuesPaid = false,
    this.orderDues = 0,
    this.orderDuesPaid = false,
    this.elevationDues = 0,
    this.elevationDuesPaid = false,
  });

  factory DuesYear.fromMap(Map<String, dynamic> map) {
    return DuesYear(
      lodgeDues: (map['lodgeDues'] ?? 0) as num,
      lodgeDuesPaid: (map['lodgeDuesPaid'] ?? false) as bool,
      orderDues: (map['orderDues'] ?? 0) as num,
      orderDuesPaid: (map['orderDuesPaid'] ?? false) as bool,
      elevationDues: (map['elevationDues'] ?? 0) as num,
      elevationDuesPaid: (map['elevationDuesPaid'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lodgeDues': lodgeDues,
      'lodgeDuesPaid': lodgeDuesPaid,
      'orderDues': orderDues,
      'orderDuesPaid': orderDuesPaid,
      'elevationDues': elevationDues,
      'elevationDuesPaid': elevationDuesPaid,
    };
  }

  DuesYear copyWith({
    num? lodgeDues,
    bool? lodgeDuesPaid,
    num? orderDues,
    bool? orderDuesPaid,
    num? elevationDues,
    bool? elevationDuesPaid,
  }) {
    return DuesYear(
      lodgeDues: lodgeDues ?? this.lodgeDues,
      lodgeDuesPaid: lodgeDuesPaid ?? this.lodgeDuesPaid,
      orderDues: orderDues ?? this.orderDues,
      orderDuesPaid: orderDuesPaid ?? this.orderDuesPaid,
      elevationDues: elevationDues ?? this.elevationDues,
      elevationDuesPaid: elevationDuesPaid ?? this.elevationDuesPaid,
    );
  }

  /// Une entrée « vierge » : mêmes montants mais tout marqué non-payé.
  DuesYear resetPaid() => copyWith(
        lodgeDuesPaid: false,
        orderDuesPaid: false,
        elevationDuesPaid: false,
      );
}

class Member {
  final String id;
  final String firstName;
  final String lastName;
  final String address;
  final String phone;
  final String email;
  final String matricule;
  final String grade; // 'Apprenti' | 'Compagnon' | 'Maitre'
  final String function;
  final String motherLodge;
  final String sponsor;
  final String loginId;
  final String password;
  final String birthDate;
  final String initiationDate;
  final String entryDate;
  final String status; // 'Actif' | 'Honoraire' | 'En sommeil' | ...
  final num lodgeDues;
  final bool lodgeDuesPaid;
  final num orderDues;
  final bool orderDuesPaid;
  final num elevationDues;
  final bool elevationDuesPaid;
  final bool isAdmin;

  /// Cotisations par année (clé = année, ex. 2024). Permet de conserver
  /// l'historique. Les champs à plat ci-dessus restent synchronisés avec
  /// l'année courante pour la compatibilité avec la version web.
  final Map<int, DuesYear> duesByYear;

  const Member({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.matricule = '',
    this.grade = 'Apprenti',
    this.function = 'Aucun',
    this.motherLodge = '',
    this.sponsor = '',
    this.loginId = '',
    this.password = '',
    this.birthDate = '',
    this.initiationDate = '',
    this.entryDate = '',
    this.status = 'Actif',
    this.lodgeDues = 0,
    this.lodgeDuesPaid = false,
    this.orderDues = 0,
    this.orderDuesPaid = false,
    this.elevationDues = 0,
    this.elevationDuesPaid = false,
    this.isAdmin = false,
    this.duesByYear = const {},
  });

  factory Member.fromMap(String id, Map<String, dynamic> map) {
    // Champs à plat (format historique / web).
    final flat = DuesYear(
      lodgeDues: (map['lodgeDues'] ?? 0) as num,
      lodgeDuesPaid: (map['lodgeDuesPaid'] ?? false) as bool,
      orderDues: (map['orderDues'] ?? 0) as num,
      orderDuesPaid: (map['orderDuesPaid'] ?? false) as bool,
      elevationDues: (map['elevationDues'] ?? 0) as num,
      elevationDuesPaid: (map['elevationDuesPaid'] ?? false) as bool,
    );

    // Cotisations par année (nouveau format).
    final Map<int, DuesYear> byYear = {};
    final rawByYear = map['duesByYear'];
    if (rawByYear is Map) {
      rawByYear.forEach((key, value) {
        final year = int.tryParse('$key');
        if (year != null && value is Map) {
          byYear[year] =
              DuesYear.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }
    // Migration : aucun historique par année -> initialiser l'année courante
    // à partir des anciens champs à plat.
    if (byYear.isEmpty) {
      byYear[DateTime.now().year] = flat;
    }

    return Member(
      id: id,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      matricule: (map['matricule'] ?? '') as String,
      grade: (map['grade'] ?? 'Apprenti') as String,
      function: (map['function'] ?? 'Aucun') as String,
      motherLodge: (map['motherLodge'] ?? '') as String,
      sponsor: (map['sponsor'] ?? '') as String,
      loginId: (map['loginId'] ?? '') as String,
      password: (map['password'] ?? '') as String,
      birthDate: (map['birthDate'] ?? '') as String,
      initiationDate: (map['initiationDate'] ?? '') as String,
      entryDate: (map['entryDate'] ?? '') as String,
      status: (map['status'] ?? 'Actif') as String,
      lodgeDues: (map['lodgeDues'] ?? 0) as num,
      lodgeDuesPaid: (map['lodgeDuesPaid'] ?? false) as bool,
      orderDues: (map['orderDues'] ?? 0) as num,
      orderDuesPaid: (map['orderDuesPaid'] ?? false) as bool,
      elevationDues: (map['elevationDues'] ?? 0) as num,
      elevationDuesPaid: (map['elevationDuesPaid'] ?? false) as bool,
      isAdmin: (map['isAdmin'] ?? false) as bool,
      duesByYear: byYear,
    );
  }

  Map<String, dynamic> toMap() {
    // Champs à plat synchronisés sur l'année courante (compat web / historique).
    final flat = duesFor(DateTime.now().year);
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'address': address,
      'phone': phone,
      'email': email,
      'matricule': matricule,
      'grade': grade,
      'function': function,
      'motherLodge': motherLodge,
      'sponsor': sponsor,
      'loginId': loginId,
      'password': password,
      'birthDate': birthDate,
      'initiationDate': initiationDate,
      'entryDate': entryDate,
      'status': status,
      'lodgeDues': flat.lodgeDues,
      'lodgeDuesPaid': flat.lodgeDuesPaid,
      'orderDues': flat.orderDues,
      'orderDuesPaid': flat.orderDuesPaid,
      'elevationDues': flat.elevationDues,
      'elevationDuesPaid': flat.elevationDuesPaid,
      'isAdmin': isAdmin,
      'duesByYear': {
        for (final e in duesByYear.entries) '${e.key}': e.value.toMap(),
      },
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  /// Années enregistrées, triées de la plus récente à la plus ancienne.
  List<int> get years {
    final list = duesByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    if (list.isEmpty) list.add(DateTime.now().year);
    return list;
  }

  /// Cotisations pour l'année demandée (entrée vierge si absente).
  DuesYear duesFor(int year) => duesByYear[year] ?? const DuesYear();

  /// Renvoie une copie avec les cotisations de [year] remplacées.
  Member withDuesForYear(int year, DuesYear dues) {
    final next = Map<int, DuesYear>.from(duesByYear);
    next[year] = dues;
    return copyWith(duesByYear: next);
  }

  Member copyWith({
    String? firstName,
    String? lastName,
    String? address,
    String? phone,
    String? email,
    String? matricule,
    String? grade,
    String? function,
    String? motherLodge,
    String? sponsor,
    String? loginId,
    String? password,
    String? birthDate,
    String? initiationDate,
    String? entryDate,
    String? status,
    num? lodgeDues,
    bool? lodgeDuesPaid,
    num? orderDues,
    bool? orderDuesPaid,
    num? elevationDues,
    bool? elevationDuesPaid,
    bool? isAdmin,
    Map<int, DuesYear>? duesByYear,
  }) {
    return Member(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      matricule: matricule ?? this.matricule,
      grade: grade ?? this.grade,
      function: function ?? this.function,
      motherLodge: motherLodge ?? this.motherLodge,
      sponsor: sponsor ?? this.sponsor,
      loginId: loginId ?? this.loginId,
      password: password ?? this.password,
      birthDate: birthDate ?? this.birthDate,
      initiationDate: initiationDate ?? this.initiationDate,
      entryDate: entryDate ?? this.entryDate,
      status: status ?? this.status,
      lodgeDues: lodgeDues ?? this.lodgeDues,
      lodgeDuesPaid: lodgeDuesPaid ?? this.lodgeDuesPaid,
      orderDues: orderDues ?? this.orderDues,
      orderDuesPaid: orderDuesPaid ?? this.orderDuesPaid,
      elevationDues: elevationDues ?? this.elevationDues,
      elevationDuesPaid: elevationDuesPaid ?? this.elevationDuesPaid,
      isAdmin: isAdmin ?? this.isAdmin,
      duesByYear: duesByYear ?? this.duesByYear,
    );
  }
}
