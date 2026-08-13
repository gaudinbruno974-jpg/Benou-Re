// Modèle d'un dignitaire (officier d'une autre loge, représentant
// d'obédience...), annoncé par le Maître des Cérémonies avant l'entrée en
// loge du Vénérable Maître. Même structure que Visitor (voir visitor.dart) :
// répertoire indépendant, présence et office pris gérés par tenue.
class Dignitary {
  final String id;
  final String firstName;
  final String lastName;

  /// Titre / qualité (« Grand Maître Adjoint », « Représentant de la R∴L∴
  /// X »). Affiché en priorité lors de l'annonce, sauf office pris ce jour-là.
  final String title;

  final String lodge;
  final String orient;
  final String obedience;
  final String email;
  final String phone;

  /// Rang protocolaire (optionnel) : plus petit = annoncé en premier. Les
  /// dignitaires sans rang sont triés par ordre alphabétique après ceux qui
  /// en ont un.
  final int? protocolRank;

  const Dignitary({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.title = '',
    this.lodge = '',
    this.orient = '',
    this.obedience = '',
    this.email = '',
    this.phone = '',
    this.protocolRank,
  });

  factory Dignitary.fromMap(String id, Map<String, dynamic> map) {
    final rank = map['protocolRank'];
    return Dignitary(
      id: id,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      lodge: (map['lodge'] ?? '') as String,
      orient: (map['orient'] ?? '') as String,
      obedience: (map['obedience'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      protocolRank: rank is num ? rank.toInt() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'title': title,
      'lodge': lodge,
      'orient': orient,
      'obedience': obedience,
      'email': email,
      'phone': phone,
      'protocolRank': protocolRank,
    };
  }

  String get fullName => '$firstName $lastName'.trim();

  Dignitary copyWith({
    String? firstName,
    String? lastName,
    String? title,
    String? lodge,
    String? orient,
    String? obedience,
    String? email,
    String? phone,
    int? protocolRank,
    bool clearProtocolRank = false,
  }) {
    return Dignitary(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      title: title ?? this.title,
      lodge: lodge ?? this.lodge,
      orient: orient ?? this.orient,
      obedience: obedience ?? this.obedience,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      protocolRank: clearProtocolRank
          ? null
          : (protocolRank ?? this.protocolRank),
    );
  }
}
