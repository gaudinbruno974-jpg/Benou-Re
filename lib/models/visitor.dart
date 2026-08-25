// Modèle d'un visiteur (porté depuis src/types.ts -> Visitor).

class Visitor {
  final String id;
  final String firstName;
  final String lastName;
  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;
  final String function;

  /// « Frère » / « Sœur », vide si non renseignée (voir civilite.dart).
  final String civilite;

  /// Grade maçonnique (Apprenti/Compagnon/Maître, voir kGrades dans
  /// member.dart) — libre comme Member.grade, non forcé à ces trois valeurs
  /// au niveau du modèle.
  final String grade;

  const Visitor({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.lodge = '',
    this.orient = '',
    this.obedience = '',
    this.email = '',
    this.phone = '',
    this.function = '',
    this.civilite = '',
    this.grade = '',
  });

  factory Visitor.fromMap(String id, Map<String, dynamic> map) {
    return Visitor(
      id: id,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      lodge: (map['lodge'] ?? '') as String,
      orient: (map['orient'] ?? '') as String,
      obedience: (map['obedience'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      function: (map['function'] ?? '') as String,
      civilite: (map['civilite'] ?? '') as String,
      grade: (map['grade'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'lodge': lodge,
      'orient': orient,
      'obedience': obedience,
      'email': email,
      'phone': phone,
      'function': function,
      'civilite': civilite,
      'grade': grade,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  Visitor copyWith({
    String? firstName,
    String? lastName,
    String? lodge,
    String? orient,
    String? obedience,
    String? email,
    String? phone,
    String? function,
    String? civilite,
    String? grade,
  }) {
    return Visitor(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      lodge: lodge ?? this.lodge,
      orient: orient ?? this.orient,
      obedience: obedience ?? this.obedience,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      function: function ?? this.function,
      civilite: civilite ?? this.civilite,
      grade: grade ?? this.grade,
    );
  }
}
