// Lien de réponse individuel (Flux A — membres de la Loge) : permet à un
// membre de déclarer sa présence à une tenue sans se connecter à
// l'application. Le jeton (UUID v4) sert d'identifiant de document Firestore
// et de preuve d'accès — voir firestore.rules pour la portée exacte des
// droits accordés à son détenteur.
import 'dart:math';

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
  final String sessionId;
  final String memberId;
  final String memberName;
  // Informations dénormalisées pour l'affichage de la page publique, qui n'a
  // pas le droit de lire la collection `sessions` (réservée aux connectés).
  final String sessionLabel;
  final String sessionDateLabel;
  final String sessionType;
  final String sessionDegreeLabel;
  final bool hasAgape;
  final String status;
  final bool? agapePresent;
  final DateTime? respondedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  /// Vrai une fois la réponse répercutée dans `session.presentIds` /
  /// `excusedIds` / `agapeIds` par un client autorisé (voir AppState).
  final bool applied;

  const PresenceLink({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.memberName,
    required this.sessionLabel,
    required this.sessionDateLabel,
    required this.sessionType,
    required this.sessionDegreeLabel,
    required this.hasAgape,
    this.status = kPresenceStatusPending,
    this.agapePresent,
    this.respondedAt,
    required this.expiresAt,
    required this.createdAt,
    this.applied = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAnswered => status != kPresenceStatusPending;
}
