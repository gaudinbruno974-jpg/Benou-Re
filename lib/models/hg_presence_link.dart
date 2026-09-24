// Lien de réponse individuel pour une tenue de Hauts Grades (IAH-MES,
// MAA-Kherou) — même principe que presence_link.dart (loges bleues) :
// permet à un destinataire de répondre sans se connecter, le jeton (UUID
// v4) servant d'identifiant de document Firestore et de preuve d'accès.
// Une seule collection partagée `hgPresenceLinks` pour les deux corps
// (plutôt qu'une collection par corps comme membres/tenues/visiteurs/
// dignitaires) : la page de réponse publique ne connaît que le jeton, pas
// le corps, et une collection unique évite de dupliquer la règle Firestore
// — [bodyKey] permet de retrouver le corps et la tenue à mettre à jour.
//
// Deux flux, comme les loges bleues :
//  - Flux A (kind = member)     : un membre du corps, réponse nominative
//    Présent/Absent (+ Agapes) — répercutée automatiquement dans la tenue.
//  - Flux B (kind = delegation) : un dignitaire invité, réponse agrégée —
//    un simple décompte de personnes de sa délégation (pas de répartition
//    par grade Apprenti/Compagnon/Maître, qui n'a pas de sens en Hauts
//    Grades — confirmé par l'utilisateur), sans distinction par grade.
import 'dart:math';

const String kHgPresenceLinkKindMember = 'member';
const String kHgPresenceLinkKindDelegation = 'delegation';

const String kHgPresenceStatusPending = 'en_attente';
const String kHgPresenceStatusPresent = 'present';
const String kHgPresenceStatusAbsent = 'absent';

/// Jeton aléatoire non devinable (128 bits), formaté en UUID v4 — même
/// génération que generatePresenceToken (presence_link.dart).
String generateHgPresenceToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

class HgPresenceLink {
  final String id; // jeton, aussi identifiant du document Firestore
  final String bodyKey; // 'iahmes' | 'maakherou' — voir models/hg_body.dart
  final String kind; // member | delegation
  final String sessionId;
  // Informations dénormalisées pour l'affichage de la page publique, qui n'a
  // pas le droit de lire la collection des tenues (réservée aux connectés).
  final String sessionLabel;
  final String sessionDateLabel;
  final String sessionType;
  final String sessionDegreeLabel;
  final bool hasAgape;

  // Flux A — membre du corps (kind == member).
  final String memberId;
  final String memberName;
  final String status; // en_attente | present | absent
  final bool? agapePresent;

  // Flux B — dignitaire invité (kind == delegation).
  final String recipientId; // id du document dignitaires du corps
  final String recipientName;

  /// Nombre de personnes de la délégation présentes, sans distinction de
  /// grade (contrairement au Flux B des loges bleues).
  final int? delegationCount;
  final bool? recipientAgapePresent;

  /// Vrai pour un dignitaire qui vient seul, sans délégation à déclarer :
  /// sa page de réponse devient un simple Présent/Absent/Agapes, comme le
  /// Flux A — voir dignitaryComesAlone (models/dignitary.dart), réutilisé
  /// tel quel (rang protocolaire 1 ou 2).
  final bool recipientAlone;

  final DateTime? respondedAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Vrai une fois la réponse d'un membre (Flux A) répercutée dans la
  /// tenue par un client autorisé — voir AppState._applyHgPresenceLinks.
  final bool applied;

  const HgPresenceLink({
    required this.id,
    required this.bodyKey,
    this.kind = kHgPresenceLinkKindMember,
    required this.sessionId,
    required this.sessionLabel,
    required this.sessionDateLabel,
    required this.sessionType,
    required this.sessionDegreeLabel,
    required this.hasAgape,
    this.memberId = '',
    this.memberName = '',
    this.status = kHgPresenceStatusPending,
    this.agapePresent,
    this.recipientId = '',
    this.recipientName = '',
    this.delegationCount,
    this.recipientAgapePresent,
    this.recipientAlone = false,
    this.respondedAt,
    required this.expiresAt,
    required this.createdAt,
    this.applied = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAnswered => respondedAt != null;

  String get displayName => memberName.isNotEmpty ? memberName : recipientName;
}
