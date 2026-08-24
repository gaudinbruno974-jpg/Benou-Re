// Registre des Tenues extérieures reçues (Bureau) : trace les invitations
// que la Loge courante reçoit d'autres Loges ou obédiences pour une tenue
// qui se déroule ailleurs, et relaie ça aux membres avec un lien de réponse
// personnel — même mécanisme que les Convocations internes (voir
// presence_link.dart, kind == kPresenceLinkKindExternal), mais sans volet
// Agapes puisque ce n'est pas une tenue organisée par la Loge courante.
import 'member.dart' show Member, kApprenti, kCompagnon, kMaitre;
import 'presence_link.dart';
import 'session.dart' show Session;

/// « Tous » s'ajoute aux trois grades pour le champ « Degré concerné » —
/// contrairement à une tenue de la Loge courante (toujours à un degré
/// précis), une invitation reçue peut explicitement s'adresser à tout
/// l'Atelier.
const String kExternalDegreeAll = 'Tous';
const List<String> kExternalDegrees = [
  kExternalDegreeAll,
  kApprenti,
  kCompagnon,
  kMaitre,
];

const String kExternalEventOrdinaire = 'Tenue ordinaire';
const String kExternalEventBlanche = 'Tenue blanche';
const String kExternalEventFunebre = 'Tenue funèbre';
const String kExternalEventConvent = 'Convent';
const String kExternalEventAutre = 'Autre';
const List<String> kExternalEventTypes = [
  kExternalEventOrdinaire,
  kExternalEventBlanche,
  kExternalEventFunebre,
  kExternalEventConvent,
  kExternalEventAutre,
];

const String kExternalContactSecretaire = 'secretaire';
const String kExternalContactVenerable = 'venerable';

class ExternalSession {
  final String id;
  final String organizingLodge;
  final String obedience;

  /// Date/heure de la tenue extérieure, ISO 8601 — même convention que
  /// `Session.date`.
  final String date;
  final String location;

  /// [kExternalDegrees].
  final String degree;

  /// [kExternalEventTypes].
  final String eventType;

  /// Libellé libre si [eventType] == [kExternalEventAutre].
  final String eventTypeOther;

  /// [kExternalContactSecretaire] / [kExternalContactVenerable] — dont les
  /// coordonnées réelles sont reprises de LodgeConfig/du Bureau au moment de
  /// la génération du texte, pas stockées ici.
  final String contactPerson;

  final String notes;

  /// Fichier du carton d'invitation original (photo/PDF), archivé sur
  /// Drive — nom, lien direct et identifiant (pour le retélécharger et le
  /// rejoindre au mail de diffusion, voir DriveService.downloadFile).
  final String attachmentFileName;
  final String attachmentDriveUrl;
  final String attachmentFileId;
  final String attachmentContentType;

  /// Membres de la Loge courante ayant confirmé leur présence — alimentée
  /// automatiquement par les réponses reçues (voir AppState），modifiable
  /// ensuite à la main par le Bureau.
  final List<String> attendingMemberIds;

  const ExternalSession({
    required this.id,
    this.organizingLodge = '',
    this.obedience = '',
    this.date = '',
    this.location = '',
    this.degree = kExternalDegreeAll,
    this.eventType = kExternalEventOrdinaire,
    this.eventTypeOther = '',
    this.contactPerson = kExternalContactSecretaire,
    this.notes = '',
    this.attachmentFileName = '',
    this.attachmentDriveUrl = '',
    this.attachmentFileId = '',
    this.attachmentContentType = '',
    this.attendingMemberIds = const [],
  });

  DateTime? get dateTime => DateTime.tryParse(date);

  /// Bascule automatique vers l'historique dès que la date est dépassée —
  /// même principe que `Session.isSuspended` : un getter calculé, aucun
  /// champ de statut stocké.
  bool get isPast {
    final dt = dateTime;
    return dt != null && DateTime.now().isAfter(dt);
  }

  /// « Tenue ordinaire », ou le libellé libre si « Autre ».
  String get eventTypeLabel =>
      eventType == kExternalEventAutre && eventTypeOther.trim().isNotEmpty
          ? eventTypeOther.trim()
          : eventType;

  factory ExternalSession.fromMap(String id, Map<String, dynamic> map) {
    return ExternalSession(
      id: id,
      organizingLodge: (map['organizingLodge'] ?? '') as String,
      obedience: (map['obedience'] ?? '') as String,
      date: (map['date'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      degree: (map['degree'] ?? kExternalDegreeAll) as String,
      eventType: (map['eventType'] ?? kExternalEventOrdinaire) as String,
      eventTypeOther: (map['eventTypeOther'] ?? '') as String,
      contactPerson:
          (map['contactPerson'] ?? kExternalContactSecretaire) as String,
      notes: (map['notes'] ?? '') as String,
      attachmentFileName: (map['attachmentFileName'] ?? '') as String,
      attachmentDriveUrl: (map['attachmentDriveUrl'] ?? '') as String,
      attachmentFileId: (map['attachmentFileId'] ?? '') as String,
      attachmentContentType: (map['attachmentContentType'] ?? '') as String,
      attendingMemberIds: (map['attendingMemberIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'organizingLodge': organizingLodge,
    'obedience': obedience,
    'date': date,
    'location': location,
    'degree': degree,
    'eventType': eventType,
    'eventTypeOther': eventTypeOther,
    'contactPerson': contactPerson,
    'notes': notes,
    'attachmentFileName': attachmentFileName,
    'attachmentDriveUrl': attachmentDriveUrl,
    'attachmentFileId': attachmentFileId,
    'attachmentContentType': attachmentContentType,
    'attendingMemberIds': attendingMemberIds,
  };

  ExternalSession copyWith({
    String? organizingLodge,
    String? obedience,
    String? date,
    String? location,
    String? degree,
    String? eventType,
    String? eventTypeOther,
    String? contactPerson,
    String? notes,
    String? attachmentFileName,
    String? attachmentDriveUrl,
    String? attachmentFileId,
    String? attachmentContentType,
    List<String>? attendingMemberIds,
  }) => ExternalSession(
    id: id,
    organizingLodge: organizingLodge ?? this.organizingLodge,
    obedience: obedience ?? this.obedience,
    date: date ?? this.date,
    location: location ?? this.location,
    degree: degree ?? this.degree,
    eventType: eventType ?? this.eventType,
    eventTypeOther: eventTypeOther ?? this.eventTypeOther,
    contactPerson: contactPerson ?? this.contactPerson,
    notes: notes ?? this.notes,
    attachmentFileName: attachmentFileName ?? this.attachmentFileName,
    attachmentDriveUrl: attachmentDriveUrl ?? this.attachmentDriveUrl,
    attachmentFileId: attachmentFileId ?? this.attachmentFileId,
    attachmentContentType: attachmentContentType ?? this.attachmentContentType,
    attendingMemberIds: attendingMemberIds ?? this.attendingMemberIds,
  );
}

/// Membres de la Loge destinataires de la diffusion, selon le degré
/// concerné : « Tous » cible tout le monde, un degré précis suit la même
/// règle maçonnique que pour une tenue de la Loge (un grade supérieur peut
/// toujours assister à un degré inférieur) — voir Session.degreeRank.
List<Member> eligibleExternalRecipients(String degree, List<Member> members) {
  if (degree.isEmpty || degree == kExternalDegreeAll) return members;
  final rank = Session.degreeRank(degree);
  return members.where((m) => Session.degreeRank(m.grade) >= rank).toList();
}

/// Répercute une réponse reçue par lien (kind == kPresenceLinkKindExternal)
/// dans `attendingMemberIds` — fonction pure, testable sans Firestore, même
/// principe que dignitariesToAnnounce/dignitaryComesAlone dans
/// dignitary.dart. Présent ajoute le membre, tout le reste (Absent, en
/// attente) l'enlève : pas de liste « excusé » dédiée pour une tenue
/// extérieure.
ExternalSession applyExternalResponse(
  ExternalSession session,
  PresenceLink link,
) {
  final attending = List<String>.from(session.attendingMemberIds)
    ..remove(link.memberId);
  if (link.status == kPresenceStatusPresent) {
    attending.add(link.memberId);
  }
  return session.copyWith(attendingMemberIds: attending);
}
