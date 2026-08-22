// Jeton de vérification du Passeport Maçonnique : preuve d'identité
// temporaire affichée en QR code plein écran par un membre, scannée par le
// Couvreur d'une autre Loge sur une page publique de vérification
// (`#/passeport/<jeton>`). Volontairement très courte durée de vie (1 heure)
// — contrairement aux liens de réponse aux convocations, un passeport
// imprimé ne peut jamais régénérer son jeton, donc son QR n'a pas vocation à
// être imprimé : seul celui généré à la demande dans l'application, juste
// avant le contrôle, doit être utilisé. Même principe de jeton non devinable
// que presence_link.dart (voir generatePresenceToken), réutilisé ici.
import 'presence_link.dart' show generatePresenceToken;

/// Jeton aléatoire non devinable (128 bits, UUID v4) — alias de
/// [generatePresenceToken], même mécanisme de génération.
String generatePassportToken() => generatePresenceToken();

class PassportToken {
  final String id; // jeton, aussi identifiant du document Firestore
  final String memberId;

  // Informations dénormalisées pour la page publique de vérification, qui
  // n'a pas le droit de lire la collection `members` (réservée aux
  // connectés) : tout ce qui doit s'afficher est recopié ici à la
  // génération du jeton.
  final String memberName;
  final String civilite;
  final String grade;
  final String initiationDate;
  final String entryDate;
  final String lodgeName;
  final String lodgeNumber;
  final String lodgeOrient;
  final String lodgeObedience;

  final DateTime createdAt;
  final DateTime expiresAt;

  const PassportToken({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.civilite = '',
    this.grade = '',
    this.initiationDate = '',
    this.entryDate = '',
    required this.lodgeName,
    required this.lodgeNumber,
    required this.lodgeOrient,
    required this.lodgeObedience,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
