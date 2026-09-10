// Modèle d'un membre de l'Atelier (porté depuis src/types.ts -> Member).

/// Graphie unique des grades / degrés, pour éviter les comparaisons sur des
/// variantes accentuées ou non.
const String kApprenti = 'Apprenti';
const String kCompagnon = 'Compagnon';
const String kMaitre = 'Maître';

const List<String> kGrades = [kApprenti, kCompagnon, kMaitre];

/// Offices de l'Atelier, dans l'ordre du tableau de Loge.
const List<String> kFunctions = [
  'Aucun',
  'Vénérable Maître',
  '1er Surveillant',
  '2nd Surveillant',
  'Orateur',
  'Secrétaire',
  'Trésorier',
  'Hospitalier',
  'Expert',
  'Maître des Cérémonies',
  'Couvreur',
  'Maître des Banquets',
  "Maître de l'Harmonie",
];

/// Minuscule sans accents, pour comparer des libellés saisis à la main.
String foldLabel(String value) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final buffer = StringBuffer();
  for (final c in value.trim().toLowerCase().split('')) {
    final i = from.indexOf(c);
    buffer.write(i == -1 ? c : to[i]);
  }
  return buffer.toString();
}

/// Ramène une graphie quelconque ('Maitre', 'maître'…) sur la constante.
String normalizeGrade(String? value) {
  final v = foldLabel(value ?? '');
  if (v.contains('maitre')) return kMaitre;
  if (v.contains('compagnon')) return kCompagnon;
  if (v.contains('apprenti')) return kApprenti;
  return value?.trim() ?? '';
}

/// Droit d'édition des tenues : V∴M∴, Secrétaire ou administrateur.
/// Même critère que le web (`canEdit` dans PlancheTraceeScreen.tsx).
bool canEditSessions(Member? user) {
  if (user == null) return false;
  if (user.isAdmin) return true;
  final fn = foldLabel(user.function);
  return fn.contains('venerable') || fn.contains('secretaire');
}

/// V∴M∴ seul (ou administrateur) — plus restrictif que [canEditSessions] :
/// réservé aux écrans Statistiques, Rapport pour la Grande Loge, et au
/// déverrouillage ponctuel d'une tenue suspendue.
bool isVenerableMaitre(Member? user) {
  if (user == null) return false;
  if (user.isAdmin) return true;
  return foldLabel(user.function).contains('venerable');
}

/// Droit d'édition de la Trésorerie : Trésorier, V∴M∴ ou administrateur.
bool canEditTreasury(Member? user) {
  if (user == null) return false;
  if (user.isAdmin) return true;
  final fn = foldLabel(user.function);
  return fn.contains('tresorier') || fn.contains('venerable');
}

/// Droit de consultation de la vue d'annonce des Dignitaires : ceux qui
/// gèrent déjà les tenues (V∴M∴, Secrétaire, administrateur), plus le
/// Maître des Cérémonies qui procède lui-même à l'annonce et n'a pas
/// forcément l'un de ces offices.
bool canViewDignitaryAnnounce(Member? user) {
  if (user == null) return false;
  if (canEditSessions(user)) return true;
  return foldLabel(user.function).contains('ceremonies');
}

/// Lecture tolérante d'un montant Firestore (num, String ou absent).
num _num(dynamic value) {
  if (value is num) return value;
  if (value is String) {
    return num.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }
  return 0;
}

/// Cotisations d'un membre pour une année donnée.
class DuesYear {
  final num lodgeDues;
  final bool lodgeDuesPaid;
  final num lodgeDuesPaidAmount;
  final num orderDues;
  final bool orderDuesPaid;
  final num orderDuesPaidAmount;
  final num elevationDues;
  final bool elevationDuesPaid;
  final num elevationDuesPaidAmount;

  /// Date de règlement (jj/mm/aaaa, saisie libre), utilisée sur le Quitus.
  final String lodgeDuesPaidDate;
  final String orderDuesPaidDate;

  /// Suivi de l'envoi de l'Appel de cotisation et du Quitus (voir
  /// treasury_documents.dart) : permet de savoir qui relancer et d'éviter
  /// les envois en double par mégarde.
  final bool appelSent;
  final String appelSentDate;
  final bool quitusSent;
  final String quitusSentDate;

  const DuesYear({
    this.lodgeDues = 0,
    this.lodgeDuesPaid = false,
    this.lodgeDuesPaidAmount = 0,
    this.orderDues = 0,
    this.orderDuesPaid = false,
    this.orderDuesPaidAmount = 0,
    this.elevationDues = 0,
    this.elevationDuesPaid = false,
    this.elevationDuesPaidAmount = 0,
    this.lodgeDuesPaidDate = '',
    this.orderDuesPaidDate = '',
    this.appelSent = false,
    this.appelSentDate = '',
    this.quitusSent = false,
    this.quitusSentDate = '',
  });

  factory DuesYear.fromMap(Map<String, dynamic> map) {
    return DuesYear(
      lodgeDues: _num(map['lodgeDues']),
      lodgeDuesPaid: (map['lodgeDuesPaid'] ?? false) as bool,
      lodgeDuesPaidAmount: _num(map['lodgeDuesPaidAmount']),
      orderDues: _num(map['orderDues']),
      orderDuesPaid: (map['orderDuesPaid'] ?? false) as bool,
      orderDuesPaidAmount: _num(map['orderDuesPaidAmount']),
      elevationDues: _num(map['elevationDues']),
      elevationDuesPaid: (map['elevationDuesPaid'] ?? false) as bool,
      elevationDuesPaidAmount: _num(map['elevationDuesPaidAmount']),
      lodgeDuesPaidDate: (map['lodgeDuesPaidDate'] ?? '') as String,
      orderDuesPaidDate: (map['orderDuesPaidDate'] ?? '') as String,
      appelSent: (map['appelSent'] ?? false) as bool,
      appelSentDate: (map['appelSentDate'] ?? '') as String,
      quitusSent: (map['quitusSent'] ?? false) as bool,
      quitusSentDate: (map['quitusSentDate'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lodgeDues': lodgeDues,
      'lodgeDuesPaid': lodgeDuesPaid,
      'lodgeDuesPaidAmount': lodgeDuesPaidAmount,
      'orderDues': orderDues,
      'orderDuesPaid': orderDuesPaid,
      'orderDuesPaidAmount': orderDuesPaidAmount,
      'elevationDues': elevationDues,
      'elevationDuesPaid': elevationDuesPaid,
      'elevationDuesPaidAmount': elevationDuesPaidAmount,
      'lodgeDuesPaidDate': lodgeDuesPaidDate,
      'orderDuesPaidDate': orderDuesPaidDate,
      'appelSent': appelSent,
      'appelSentDate': appelSentDate,
      'quitusSent': quitusSent,
      'quitusSentDate': quitusSentDate,
    };
  }

  DuesYear copyWith({
    num? lodgeDues,
    bool? lodgeDuesPaid,
    num? lodgeDuesPaidAmount,
    num? orderDues,
    bool? orderDuesPaid,
    num? orderDuesPaidAmount,
    num? elevationDues,
    bool? elevationDuesPaid,
    num? elevationDuesPaidAmount,
    String? lodgeDuesPaidDate,
    String? orderDuesPaidDate,
    bool? appelSent,
    String? appelSentDate,
    bool? quitusSent,
    String? quitusSentDate,
  }) {
    return DuesYear(
      lodgeDues: lodgeDues ?? this.lodgeDues,
      lodgeDuesPaid: lodgeDuesPaid ?? this.lodgeDuesPaid,
      lodgeDuesPaidAmount: lodgeDuesPaidAmount ?? this.lodgeDuesPaidAmount,
      orderDues: orderDues ?? this.orderDues,
      orderDuesPaid: orderDuesPaid ?? this.orderDuesPaid,
      orderDuesPaidAmount: orderDuesPaidAmount ?? this.orderDuesPaidAmount,
      elevationDues: elevationDues ?? this.elevationDues,
      elevationDuesPaid: elevationDuesPaid ?? this.elevationDuesPaid,
      elevationDuesPaidAmount:
          elevationDuesPaidAmount ?? this.elevationDuesPaidAmount,
      lodgeDuesPaidDate: lodgeDuesPaidDate ?? this.lodgeDuesPaidDate,
      orderDuesPaidDate: orderDuesPaidDate ?? this.orderDuesPaidDate,
      appelSent: appelSent ?? this.appelSent,
      appelSentDate: appelSentDate ?? this.appelSentDate,
      quitusSent: quitusSent ?? this.quitusSent,
      quitusSentDate: quitusSentDate ?? this.quitusSentDate,
    );
  }

  /// Une entrée « vierge » : mêmes montants mais tout marqué non-payé.
  DuesYear resetPaid() => copyWith(
        lodgeDuesPaid: false,
        lodgeDuesPaidAmount: 0,
        orderDuesPaid: false,
        orderDuesPaidAmount: 0,
        elevationDuesPaid: false,
        elevationDuesPaidAmount: 0,
        lodgeDuesPaidDate: '',
        orderDuesPaidDate: '',
        quitusSent: false,
        quitusSentDate: '',
      );

  /// Vrai une fois les deux lignes (Loge et Ordre) intégralement réglées —
  /// c'est à ce moment qu'un Quitus (document unique, combiné) peut être émis.
  bool get fullyPaid => lodgeDuesPaid && orderDuesPaid;

  /// Montant réellement encaissé pour une ligne : la totalité si la ligne est
  /// marquée « soldée », sinon le versement partiel (borné au montant dû).
  static num _collected(num dues, bool paid, num paidAmount) {
    if (paid) return dues;
    if (paidAmount <= 0) return 0;
    return paidAmount > dues ? dues : paidAmount;
  }

  num get lodgeCollected =>
      _collected(lodgeDues, lodgeDuesPaid, lodgeDuesPaidAmount);
  num get orderCollected =>
      _collected(orderDues, orderDuesPaid, orderDuesPaidAmount);
  num get elevationCollected =>
      _collected(elevationDues, elevationDuesPaid, elevationDuesPaidAmount);

  num get totalDues => lodgeDues + orderDues + elevationDues;
  num get totalCollected =>
      lodgeCollected + orderCollected + elevationCollected;
  num get totalPending => totalDues - totalCollected;

  /// Recalcule les booléens « soldé » à partir des versements enregistrés.
  DuesYear syncPaidFlags() => copyWith(
        lodgeDuesPaid: _settled(lodgeDues, lodgeDuesPaidAmount),
        orderDuesPaid: _settled(orderDues, orderDuesPaidAmount),
        elevationDuesPaid: _settled(elevationDues, elevationDuesPaidAmount),
      );

  static bool _settled(num dues, num paidAmount) =>
      paidAmount > 0 && paidAmount >= dues;
}

class Member {
  final String id;
  final String firstName;
  final String lastName;
  final String address;
  final String phone;
  final String email;
  final String matricule;
  final String grade; // kApprenti | kCompagnon | kMaitre
  final String function;

  /// « Frère » / « Sœur », vide si non renseignée (voir civilite.dart).
  final String civilite;

  /// Canal préféré pour les invitations individuelles (« WhatsApp » /
  /// « Courriel »), vide si non renseigné — voir preferred_contact.dart.
  final String preferredContact;
  final String motherLodge;
  final String sponsor;
  final String loginId;

  /// Identifiant Firebase Auth du compte de connexion. Lien stable : il
  /// survit à un changement d'adresse e-mail.
  final String authUid;

  /// Adresse servant d'identifiant de connexion, quand elle diffère de
  /// l'e-mail de contact. Vide = l'e-mail de contact fait foi.
  final String loginEmail;
  final String birthDate;
  final String initiationDate;
  final String entryDate;
  final String status; // 'Actif' | 'Honoraire' | 'En sommeil' | ...
  final num lodgeDues;
  final bool lodgeDuesPaid;
  final num lodgeDuesPaidAmount;
  final num orderDues;
  final bool orderDuesPaid;
  final num orderDuesPaidAmount;
  final num elevationDues;
  final bool elevationDuesPaid;
  final num elevationDuesPaidAmount;
  final bool isAdmin;

  /// Degré aux Hauts Grades (ex. « 18e degré »), axe totalement distinct du
  /// grade symbolique de loge bleue ([grade]) — un Maître en loge bleue peut
  /// être à un degré quelconque, ou aucun, aux Hauts Grades. Réservé à
  /// l'administrateur : jamais affiché ni exporté côté loge bleue (voir
  /// [canViewHautsGrades]).
  final String hautsGradesDegree;

  /// Code de rôle stable (ex. « sgm », « gm », « admin »), pour le flavor
  /// Grande Loge — distinct de [function], qui reste le libellé d'office
  /// affiché (« Sérénissime Grand Maître »). Vide et sans usage pour les
  /// quatre loges bleues.
  final String role;

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
    this.grade = kApprenti,
    this.function = 'Aucun',
    this.civilite = '',
    this.preferredContact = '',
    this.motherLodge = '',
    this.sponsor = '',
    this.loginId = '',
    this.authUid = '',
    this.loginEmail = '',
    this.birthDate = '',
    this.initiationDate = '',
    this.entryDate = '',
    this.status = 'Actif',
    this.lodgeDues = 0,
    this.lodgeDuesPaid = false,
    this.lodgeDuesPaidAmount = 0,
    this.orderDues = 0,
    this.orderDuesPaid = false,
    this.orderDuesPaidAmount = 0,
    this.elevationDues = 0,
    this.elevationDuesPaid = false,
    this.elevationDuesPaidAmount = 0,
    this.isAdmin = false,
    this.hautsGradesDegree = '',
    this.role = '',
    this.duesByYear = const {},
  });

  factory Member.fromMap(String id, Map<String, dynamic> map) {
    // Champs à plat (format historique / web).
    final flat = DuesYear.fromMap(map);

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
      grade: normalizeGrade(map['grade'] as String?),
      function: (map['function'] ?? 'Aucun') as String,
      civilite: (map['civilite'] ?? '') as String,
      preferredContact: (map['preferredContact'] ?? '') as String,
      motherLodge: (map['motherLodge'] ?? '') as String,
      sponsor: (map['sponsor'] ?? '') as String,
      loginId: (map['loginId'] ?? '') as String,
      authUid: (map['authUid'] ?? '') as String,
      loginEmail: (map['loginEmail'] ?? '') as String,
      birthDate: (map['birthDate'] ?? '') as String,
      initiationDate: (map['initiationDate'] ?? '') as String,
      entryDate: (map['entryDate'] ?? '') as String,
      status: (map['status'] ?? 'Actif') as String,
      lodgeDues: flat.lodgeDues,
      lodgeDuesPaid: flat.lodgeDuesPaid,
      lodgeDuesPaidAmount: flat.lodgeDuesPaidAmount,
      orderDues: flat.orderDues,
      orderDuesPaid: flat.orderDuesPaid,
      orderDuesPaidAmount: flat.orderDuesPaidAmount,
      elevationDues: flat.elevationDues,
      elevationDuesPaid: flat.elevationDuesPaid,
      elevationDuesPaidAmount: flat.elevationDuesPaidAmount,
      isAdmin: (map['isAdmin'] ?? false) as bool,
      hautsGradesDegree: (map['hautsGradesDegree'] ?? '') as String,
      role: (map['role'] ?? '') as String,
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
      'civilite': civilite,
      'preferredContact': preferredContact,
      'motherLodge': motherLodge,
      'sponsor': sponsor,
      'loginId': loginId,
      'authUid': authUid,
      'loginEmail': loginEmail,
      'birthDate': birthDate,
      'initiationDate': initiationDate,
      'entryDate': entryDate,
      'status': status,
      'lodgeDues': flat.lodgeDues,
      'lodgeDuesPaid': flat.lodgeDuesPaid,
      'lodgeDuesPaidAmount': flat.lodgeDuesPaidAmount,
      'orderDues': flat.orderDues,
      'orderDuesPaid': flat.orderDuesPaid,
      'orderDuesPaidAmount': flat.orderDuesPaidAmount,
      'elevationDues': flat.elevationDues,
      'elevationDuesPaid': flat.elevationDuesPaid,
      'elevationDuesPaidAmount': flat.elevationDuesPaidAmount,
      'isAdmin': isAdmin,
      'hautsGradesDegree': hautsGradesDegree,
      'role': role,
      'duesByYear': {
        for (final e in duesByYear.entries) '${e.key}': e.value.toMap(),
      },
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  /// Adresse à laquelle le membre se connecte : son identifiant dédié s'il en
  /// a un, sinon son e-mail de contact.
  String get effectiveLoginEmail =>
      loginEmail.trim().isNotEmpty ? loginEmail.trim() : email.trim();

  /// Années enregistrées, triées de la plus récente à la plus ancienne.
  List<int> get years {
    final list = duesByYear.keys.toList()..sort((a, b) => b.compareTo(a));
    if (list.isEmpty) list.add(DateTime.now().year);
    return list;
  }

  /// Statuts exonérés de cotisation (Honoraire / En sommeil).
  bool get isExemptFromDues {
    final s = status.trim().toLowerCase();
    return s == 'honoraire' || s == 'en sommeil';
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
    String? civilite,
    String? preferredContact,
    String? motherLodge,
    String? sponsor,
    String? loginId,
    String? authUid,
    String? loginEmail,
    String? birthDate,
    String? initiationDate,
    String? entryDate,
    String? status,
    num? lodgeDues,
    bool? lodgeDuesPaid,
    num? lodgeDuesPaidAmount,
    num? orderDues,
    bool? orderDuesPaid,
    num? orderDuesPaidAmount,
    num? elevationDues,
    bool? elevationDuesPaid,
    num? elevationDuesPaidAmount,
    bool? isAdmin,
    String? hautsGradesDegree,
    String? role,
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
      civilite: civilite ?? this.civilite,
      preferredContact: preferredContact ?? this.preferredContact,
      motherLodge: motherLodge ?? this.motherLodge,
      sponsor: sponsor ?? this.sponsor,
      loginId: loginId ?? this.loginId,
      authUid: authUid ?? this.authUid,
      loginEmail: loginEmail ?? this.loginEmail,
      birthDate: birthDate ?? this.birthDate,
      initiationDate: initiationDate ?? this.initiationDate,
      entryDate: entryDate ?? this.entryDate,
      status: status ?? this.status,
      lodgeDues: lodgeDues ?? this.lodgeDues,
      lodgeDuesPaid: lodgeDuesPaid ?? this.lodgeDuesPaid,
      lodgeDuesPaidAmount: lodgeDuesPaidAmount ?? this.lodgeDuesPaidAmount,
      orderDues: orderDues ?? this.orderDues,
      orderDuesPaid: orderDuesPaid ?? this.orderDuesPaid,
      orderDuesPaidAmount: orderDuesPaidAmount ?? this.orderDuesPaidAmount,
      elevationDues: elevationDues ?? this.elevationDues,
      elevationDuesPaid: elevationDuesPaid ?? this.elevationDuesPaid,
      elevationDuesPaidAmount:
          elevationDuesPaidAmount ?? this.elevationDuesPaidAmount,
      isAdmin: isAdmin ?? this.isAdmin,
      hautsGradesDegree: hautsGradesDegree ?? this.hautsGradesDegree,
      role: role ?? this.role,
      duesByYear: duesByYear ?? this.duesByYear,
    );
  }
}

/// Consultation et modification du degré aux Hauts Grades ([Member.
/// hautsGradesDegree]) : réservé à l'administrateur, jamais au V∴M∴, au
/// Secrétaire ni au reste du bureau, même sur leur propre loge — axe
/// totalement séparé de [canEditSessions].
bool canViewHautsGrades(Member? user) => user?.isAdmin ?? false;
