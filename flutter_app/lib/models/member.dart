// Modèle d'un membre de l'Atelier (porté depuis src/types.ts -> Member).

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
  });

  factory Member.fromMap(String id, Map<String, dynamic> map) {
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
    );
  }

  Map<String, dynamic> toMap() {
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
      'lodgeDues': lodgeDues,
      'lodgeDuesPaid': lodgeDuesPaid,
      'orderDues': orderDues,
      'orderDuesPaid': orderDuesPaid,
      'elevationDues': elevationDues,
      'elevationDuesPaid': elevationDuesPaid,
      'isAdmin': isAdmin,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

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
    );
  }
}
