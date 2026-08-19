// Lien de réponse individuel : permet à un destinataire de répondre à une
// tenue sans se connecter à l'application. Le jeton (UUID v4) sert
// d'identifiant de document Firestore et de preuve d'accès — voir
// firestore.rules pour la portée exacte des droits accordés à son détenteur.
//
// Deux flux, un seul modèle (même jeton, mêmes règles, même page publique) :
//  - Flux A (kind = member)     : un membre de la Loge, réponse nominative
//    Présent/Absent (+ Agapes) — répercutée automatiquement dans la tenue.
//  - Flux B (kind = delegation) : un dignitaire ou un Vénérable d'une autre
//    Loge (même collection `dignitaries`), réponse agrégée par grade — une
//    déclaration d'effectifs, non rattachée à une fiche nommée.
import 'dart:math';

const String kPresenceLinkKindMember = 'member';
const String kPresenceLinkKindDelegation = 'delegation';

const String kPresenceStatusPending = 'en_attente';
const String kPresenceStatusPresent = 'present';
const String kPresenceStatusAbsent = 'absent';

/// Jeton aléatoire non devinable (128 bits), formaté en UUID v4.
String generatePresenceToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

class PresenceLink {
  final String id; // jeton, aussi identifiant du document Firestore
  final String kind; // member | delegation
  final String sessionId;
  // Informations dénormalisées pour l'affichage de la page publique, qui n'a
  // pas le droit de lire la collection `sessions` (réservée aux connectés).
  final String sessionLabel;
  final String sessionDateLabel;
  final String sessionType;
  final String sessionDegreeLabel;
  final bool hasAgape;

  // Flux A — membre de la Loge (kind == member).
  final String memberId;
  final String memberName;
  final String status; // en_attente | present | absent
  final bool? agapePresent;

  // Flux B — dignitaire / Vénérable d'une autre Loge (kind == delegation).
  final String recipientId; // id du document `dignitaries`
  final String recipientName;
  final int? apprentiCount;
  final int? compagnonCount;
  final int? maitreCount;
  final int? agapeTotal;

  final DateTime? respondedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  /// Vrai une fois la réponse d'un membre (Flux A) répercutée dans
  /// `session.presentIds` / `excusedIds` / `agapeIds` par un client autorisé
  /// (voir AppState). Sans objet pour le Flux B, qui n'alimente aucune fiche
  /// nommée et reste lu en direct depuis l'écran Invitations.
  final bool applied;

  const PresenceLink({
    required this.id,
    this.kind = kPresenceLinkKindMember,
    required this.sessionId,
    required this.sessionLabel,
    required this.sessionDateLabel,
    required this.sessionType,
    required this.sessionDegreeLabel,
    required this.hasAgape,
    this.memberId = '',
    this.memberName = '',
    this.status = kPresenceStatusPending,
    this.agapePresent,
    this.recipientId = '',
    this.recipientName = '',
    this.apprentiCount,
    this.compagnonCount,
    this.maitreCount,
    this.agapeTotal,
    this.respondedAt,
    required this.expiresAt,
    required this.createdAt,
    this.applied = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAnswered => respondedAt != null;
}
