// Modèle d'un dignitaire (officier d'une autre loge, représentant
// d'obédience...), annoncé par le Maître des Cérémonies avant l'entrée en
// loge du Vénérable Maître. Même structure que Visitor (voir visitor.dart) :
// répertoire indépendant, présence et office pris gérés par tenue.
import 'member.dart' show foldLabel;
import 'session.dart';

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

  /// « Frère » / « Sœur », vide si non renseignée (voir civilite.dart).
  final String civilite;

  /// Canal préféré pour les invitations individuelles (« WhatsApp » /
  /// « Courriel »), vide si non renseigné — voir preferred_contact.dart.
  final String preferredContact;

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
    this.civilite = '',
    this.preferredContact = '',
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
      civilite: (map['civilite'] ?? '') as String,
      preferredContact: (map['preferredContact'] ?? '') as String,
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
      'civilite': civilite,
      'preferredContact': preferredContact,
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
    String? civilite,
    String? preferredContact,
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
      civilite: civilite ?? this.civilite,
      preferredContact: preferredContact ?? this.preferredContact,
      protocolRank: clearProtocolRank
          ? null
          : (protocolRank ?? this.protocolRank),
    );
  }
}

/// Dignitaires à annoncer par le Maître des Cérémonies avant l'entrée en
/// loge du Vénérable Maître, dans l'ordre d'annonce.
///
/// Un dignitaire ayant pris un office ce jour-là (Second Surveillant,
/// Orateur...) entre en loge avec le collège des officiers : il n'est pas
/// annoncé séparément — voir buildPlancheTraceeText dans pdf_service.dart,
/// qui lui réserve déjà sa propre phrase de placement. Seuls les
/// dignitaires sans office, placés à l'Orient par défaut, sont annoncés.
/// Le Vénérable Maître (de sa propre Loge) est toujours annoncé en premier,
/// avant le tri par rang protocolaire.
List<Dignitary> dignitariesToAnnounce(
  Session session,
  List<Dignitary> allDignitaries,
) {
  bool hasOfficeToday(Dignitary d) =>
      (session.dignitaryRoles[d.id] ?? '').trim().isNotEmpty;
  bool isVenerable(Dignitary d) =>
      foldLabel(d.title).contains('venerable maitre');

  return allDignitaries
      .where(
        (d) => session.dignitaryIds.contains(d.id) && !hasOfficeToday(d),
      )
      .toList()
    ..sort((a, b) {
      final va = isVenerable(a);
      final vb = isVenerable(b);
      if (va != vb) return va ? -1 : 1;
      final ra = a.protocolRank;
      final rb = b.protocolRank;
      if (ra != null && rb != null) {
        final cmp = ra.compareTo(rb);
        if (cmp != 0) return cmp;
      } else if (ra != null) {
        return -1;
      } else if (rb != null) {
        return 1;
      }
      return a.lastName.compareTo(b.lastName);
    });
}
