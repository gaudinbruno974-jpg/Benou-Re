// Accès Firestore (porté depuis src/lib/firebaseSync.ts).
// Collections : members, sessions, visitors, dignitaries, config.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/drive_access_folder.dart';
import '../models/external_session.dart';
import '../models/inventory_check.dart';
import '../models/inventory_item.dart';
import '../models/member.dart';
import '../models/member_event.dart';
import '../models/passport_token.dart';
import '../models/presence_link.dart';
import '../models/session.dart';
import '../models/visitor.dart';

class FirestoreRepository {
  final FirebaseFirestore _db;

  FirestoreRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ─── Members ──────────────────────────────────────────────────
  Stream<List<Member>> membersStream() {
    return _db.collection('members').snapshots().map(
          (snap) => snap.docs
              .map((d) => Member.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setMember(Member member) {
    return _db.collection('members').doc(member.id).set(member.toMap());
  }

  Future<void> deleteMember(String id) {
    return _db.collection('members').doc(id).delete();
  }

  Future<Member?> findMemberByEmail(String email) async {
    final snap = await _db
        .collection('members')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Member.fromMap(d.id, d.data());
  }

  // ─── Historique des membres (élévations, changements de statut) ─
  Stream<List<MemberEvent>> memberEventsStream() {
    return _db.collection('memberEvents').snapshots().map(
          (snap) => snap.docs
              .map((d) => MemberEvent.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setMemberEvent(MemberEvent event) {
    return _db.collection('memberEvents').doc(event.id).set(event.toMap());
  }

  Future<void> deleteMemberEvent(String id) {
    return _db.collection('memberEvents').doc(id).delete();
  }

  // ─── Sessions ─────────────────────────────────────────────────
  Stream<List<Session>> sessionsStream() {
    return _db.collection('sessions').snapshots().map((snap) {
      final items =
          snap.docs.map((d) => Session.fromMap(d.id, d.data())).toList();
      items.sort((a, b) {
        final ta = a.dateTime?.millisecondsSinceEpoch ?? 0;
        final tb = b.dateTime?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta); // plus récent en premier
      });
      return items;
    });
  }

  Future<void> setSession(Session session) {
    return _db.collection('sessions').doc(session.id).set(session.toMap());
  }

  Future<void> deleteSession(String id) {
    return _db.collection('sessions').doc(id).delete();
  }

  /// Lecture ponctuelle d'une tenue (hors flux temps réel), utilisée par la
  /// synchronisation des réponses reçues par lien (voir AppState) pour
  /// repartir d'un état à jour avant chaque écriture.
  Future<Session?> getSession(String id) async {
    final doc = await _db.collection('sessions').doc(id).get();
    if (!doc.exists) return null;
    return Session.fromMap(doc.id, doc.data()!);
  }

  // ─── Registre des Tenues extérieures ────────────────────────────
  Stream<List<ExternalSession>> externalSessionsStream() {
    return _db.collection('externalSessions').snapshots().map((snap) {
      final items = snap.docs
          .map((d) => ExternalSession.fromMap(d.id, d.data()))
          .toList();
      items.sort((a, b) {
        final ta = a.dateTime?.millisecondsSinceEpoch ?? 0;
        final tb = b.dateTime?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb); // plus proche en premier
      });
      return items;
    });
  }

  Future<void> setExternalSession(ExternalSession session) {
    return _db
        .collection('externalSessions')
        .doc(session.id)
        .set(session.toMap());
  }

  Future<void> deleteExternalSession(String id) {
    return _db.collection('externalSessions').doc(id).delete();
  }

  /// Lecture ponctuelle (hors flux temps réel), utilisée par la
  /// synchronisation des réponses reçues par lien (voir AppState) pour
  /// repartir d'un état à jour avant chaque écriture.
  Future<ExternalSession?> getExternalSession(String id) async {
    final doc = await _db.collection('externalSessions').doc(id).get();
    if (!doc.exists) return null;
    return ExternalSession.fromMap(doc.id, doc.data()!);
  }

  // ─── Visitors ─────────────────────────────────────────────────
  Stream<List<Visitor>> visitorsStream() {
    return _db.collection('visitors').snapshots().map(
          (snap) => snap.docs
              .map((d) => Visitor.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setVisitor(Visitor visitor) {
    return _db.collection('visitors').doc(visitor.id).set(visitor.toMap());
  }

  Future<void> deleteVisitor(String id) {
    return _db.collection('visitors').doc(id).delete();
  }

  // ─── Dignitaries ──────────────────────────────────────────────
  Stream<List<Dignitary>> dignitariesStream() {
    return _db.collection('dignitaries').snapshots().map(
          (snap) => snap.docs
              .map((d) => Dignitary.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setDignitary(Dignitary dignitary) {
    return _db
        .collection('dignitaries')
        .doc(dignitary.id)
        .set(dignitary.toMap());
  }

  Future<void> deleteDignitary(String id) {
    return _db.collection('dignitaries').doc(id).delete();
  }

  // ─── Réglages de la Loge (config/settings) ────────────────────
  /// Nom du V∴M∴ en charge, utilisé par défaut sur les planches et
  /// l'émargement quand la tenue ne le précise pas.
  Stream<String> lodgeVmNameStream() {
    return _db.collection('config').doc('settings').snapshots().map(
          (snap) => (snap.data()?['vmName'] ?? '') as String,
        );
  }

  Future<void> setLodgeVmName(String name) {
    return _db.collection('config').doc('settings').set(
      {'vmName': name.trim()},
      SetOptions(merge: true),
    );
  }

  /// Identité de la Loge (nom, orient, lieu, dossiers Drive), fusionnée avec
  /// les valeurs du flavor : une loge ne renseigne que ce qui la distingue, et
  /// l'application reste correcte si le document est absent.
  Stream<LodgeConfig> lodgeConfigStream() {
    return _db.collection('config').doc('settings').snapshots().map((snap) {
      final fallback = LodgeConfig.forCurrentFlavor;
      final data = snap.data();
      if (data == null) return fallback;
      return fallback.mergedWith(data);
    });
  }

  // ─── Inventaire du matériel de Loge ────────────────────────────
  // Module autonome, sans lien avec les tenues (voir InventoryScreen).
  Stream<List<InventoryItem>> inventoryItemsStream() {
    return _db.collection('inventoryItems').snapshots().map(
          (snap) => snap.docs
              .map((d) => InventoryItem.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Future<void> setInventoryItem(InventoryItem item) {
    return _db.collection('inventoryItems').doc(item.id).set(item.toMap());
  }

  Future<void> deleteInventoryItem(String id) {
    return _db.collection('inventoryItems').doc(id).delete();
  }

  Stream<List<InventoryCheck>> inventoryChecksStream() {
    return _db.collection('inventoryChecks').snapshots().map((snap) {
      final items = snap.docs
          .map((d) => InventoryCheck.fromMap(d.id, d.data()))
          .toList();
      items.sort((a, b) => b.performedAt.compareTo(a.performedAt));
      return items;
    });
  }

  Future<void> addInventoryCheck(InventoryCheck check) {
    return _db.collection('inventoryChecks').doc(check.id).set(check.toMap());
  }

  // ─── Liens de réponse individuels (collecte de présence sans connexion) ─
  // Flux A (membres de la Loge) et Flux B (dignitaire/Vénérable d'une autre
  // Loge, même collection `dignitaries`) — voir presence_link.dart.
  PresenceLink _presenceLinkFromDoc(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    int? intOrNull(dynamic v) => v is num ? v.toInt() : null;
    return PresenceLink(
      id: id,
      kind: (map['kind'] ?? kPresenceLinkKindMember) as String,
      sessionId: (map['sessionId'] ?? '') as String,
      sessionLabel: (map['sessionLabel'] ?? '') as String,
      sessionDateLabel: (map['sessionDateLabel'] ?? '') as String,
      sessionType: (map['sessionType'] ?? '') as String,
      sessionDegreeLabel: (map['sessionDegreeLabel'] ?? '') as String,
      hasAgape: (map['hasAgape'] ?? false) as bool,
      memberId: (map['memberId'] ?? '') as String,
      memberName: (map['memberName'] ?? '') as String,
      status: (map['status'] ?? kPresenceStatusPending) as String,
      agapePresent: map['agapePresent'] as bool?,
      recipientId: (map['recipientId'] ?? '') as String,
      recipientName: (map['recipientName'] ?? '') as String,
      apprentiCount: intOrNull(map['apprentiCount']),
      compagnonCount: intOrNull(map['compagnonCount']),
      maitreCount: intOrNull(map['maitreCount']),
      agapeTotal: intOrNull(map['agapeTotal']),
      recipientAgapePresent: map['recipientAgapePresent'] as bool?,
      recipientAlone: (map['recipientAlone'] ?? false) as bool,
      respondedAt: ts(map['respondedAt']),
      expiresAt: ts(map['expiresAt']) ?? DateTime.now(),
      createdAt: ts(map['createdAt']) ?? DateTime.now(),
      applied: (map['applied'] ?? false) as bool,
    );
  }

  Map<String, dynamic> _presenceLinkToDoc(PresenceLink link) {
    return {
      'kind': link.kind,
      'sessionId': link.sessionId,
      'sessionLabel': link.sessionLabel,
      'sessionDateLabel': link.sessionDateLabel,
      'sessionType': link.sessionType,
      'sessionDegreeLabel': link.sessionDegreeLabel,
      'hasAgape': link.hasAgape,
      'memberId': link.memberId,
      'memberName': link.memberName,
      'status': link.status,
      if (link.agapePresent != null) 'agapePresent': link.agapePresent,
      'recipientId': link.recipientId,
      'recipientName': link.recipientName,
      if (link.apprentiCount != null) 'apprentiCount': link.apprentiCount,
      if (link.compagnonCount != null) 'compagnonCount': link.compagnonCount,
      if (link.maitreCount != null) 'maitreCount': link.maitreCount,
      if (link.agapeTotal != null) 'agapeTotal': link.agapeTotal,
      if (link.recipientAgapePresent != null)
        'recipientAgapePresent': link.recipientAgapePresent,
      'recipientAlone': link.recipientAlone,
      if (link.respondedAt != null)
        'respondedAt': Timestamp.fromDate(link.respondedAt!),
      'expiresAt': Timestamp.fromDate(link.expiresAt),
      'createdAt': Timestamp.fromDate(link.createdAt),
      'applied': link.applied,
    };
  }

  Future<void> createPresenceLink(PresenceLink link) {
    return _db
        .collection('presenceLinks')
        .doc(link.id)
        .set(_presenceLinkToDoc(link));
  }

  /// Lecture publique d'un jeton précis — seul accès autorisé par les règles
  /// à un visiteur non connecté (voir firestore.rules : `allow get`, jamais
  /// `allow list`).
  Future<PresenceLink?> getPresenceLink(String token) async {
    final doc = await _db.collection('presenceLinks').doc(token).get();
    if (!doc.exists) return null;
    return _presenceLinkFromDoc(doc.id, doc.data()!);
  }

  /// Écriture publique de la réponse : les règles Firestore limitent cette
  /// mise à jour aux seuls champs `status` / `agapePresent` / `respondedAt` /
  /// `applied`, et uniquement avant expiration du jeton. `applied` est
  /// systématiquement remis à `false` : une réponse modifiée après la
  /// première (ex. Présent → Absent) doit être reprise par le flux
  /// d'application automatique (voir AppState._applyPresenceLinks), qui ne
  /// retraite sinon jamais un jeton déjà marqué appliqué.
  Future<void> submitPresenceResponse(
    String token, {
    required String status,
    bool? agapePresent,
  }) {
    final data = <String, dynamic>{
      'status': status,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'applied': false,
    };
    if (agapePresent != null) data['agapePresent'] = agapePresent;
    return _db.collection('presenceLinks').doc(token).update(data);
  }

  /// Écriture publique de la réponse d'un dignitaire venant avec une
  /// délégation (Flux B, rang 3+) : sa propre présence — `status` /
  /// `recipientAgapePresent`, appliquée automatiquement comme pour un
  /// dignitaire venant seul — et le décompte de sa délégation, qui reste
  /// purement informatif (aucune fiche nommée à cocher automatiquement).
  /// Même portée de champs modifiables que [submitPresenceResponse], voir
  /// firestore.rules ; `applied` est de même remis à `false` à chaque envoi.
  Future<void> submitDelegationResponse(
    String token, {
    required String status,
    required int apprentiCount,
    required int compagnonCount,
    required int maitreCount,
    required int agapeTotal,
    bool? recipientAgapePresent,
  }) {
    return _db.collection('presenceLinks').doc(token).update({
      'status': status,
      'apprentiCount': apprentiCount,
      'compagnonCount': compagnonCount,
      'maitreCount': maitreCount,
      'agapeTotal': agapeTotal,
      if (recipientAgapePresent != null)
        'recipientAgapePresent': recipientAgapePresent,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'applied': false,
    });
  }

  /// Réaligne `recipientAlone` d'un lien déjà généré sur le rang actuel du
  /// dignitaire (voir dignitaryComesAlone) — écriture ciblée, ne touche à
  /// rien d'autre : une réponse déjà reçue reste intacte. Nécessaire car ce
  /// champ est figé à la génération du lien (dénormalisé pour la page
  /// publique, qui ne peut pas lire `dignitaries`) et ne suit donc pas
  /// automatiquement un changement de rang ultérieur.
  Future<void> syncPresenceLinkRecipientAlone(String token, bool alone) {
    return _db.collection('presenceLinks').doc(token).update({
      'recipientAlone': alone,
    });
  }

  /// Jetons déjà émis pour une tenue (évite les doublons en réouvrant l'écran
  /// Invitations) et suivi en temps réel des réponses reçues.
  Stream<List<PresenceLink>> presenceLinksForSessionStream(String sessionId) {
    return _db
        .collection('presenceLinks')
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => _presenceLinkFromDoc(d.id, d.data()))
              .toList(),
        );
  }

  /// Réponses reçues par lien, pas encore répercutées dans la tenue
  /// concernée (voir AppState, qui applique puis marque `applied`) : Flux A
  /// (membre) et Flux B (dignitaire), qu'il vienne seul (rang 1/2) ou avec
  /// une délégation (rang 3+) — dans les deux cas sa propre présence
  /// (`status` / agapes) est une réponse nominative. Seul le décompte de
  /// délégation d'un dignitaire du rang 3+ n'alimente aucune fiche nommée et
  /// reste hors de ce flux — lu en direct par l'écran Invitations via
  /// [presenceLinksForSessionStream]. `applied` est remis à `false` à
  /// chaque nouvelle soumission (voir submitPresenceResponse /
  /// submitDelegationResponse), donc une réponse modifiée est reprise ici
  /// comme la première.
  Stream<List<PresenceLink>> unappliedPresenceLinksStream() {
    return _db
        .collection('presenceLinks')
        .where('applied', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => _presenceLinkFromDoc(d.id, d.data()))
              .where((l) => l.isAnswered)
              .toList(),
        );
  }

  Future<void> markPresenceLinkApplied(String token) {
    return _db
        .collection('presenceLinks')
        .doc(token)
        .update({'applied': true});
  }

  // ─── Passeport Maçonnique (jetons de vérification) ─────────────
  Future<void> createPassportToken(PassportToken token) {
    return _db.collection('passportTokens').doc(token.id).set({
      'memberId': token.memberId,
      'memberName': token.memberName,
      'civilite': token.civilite,
      'grade': token.grade,
      'initiationDate': token.initiationDate,
      'entryDate': token.entryDate,
      'lodgeName': token.lodgeName,
      'lodgeNumber': token.lodgeNumber,
      'lodgeOrient': token.lodgeOrient,
      'lodgeObedience': token.lodgeObedience,
      'createdAt': Timestamp.fromDate(token.createdAt),
      'expiresAt': Timestamp.fromDate(token.expiresAt),
    });
  }

  /// Lecture publique d'un jeton précis — même principe que
  /// [getPresenceLink] : seul accès autorisé par les règles à un visiteur
  /// non connecté (`allow get`, jamais `allow list`).
  Future<PassportToken?> getPassportToken(String token) async {
    final doc = await _db.collection('passportTokens').doc(token).get();
    if (!doc.exists) return null;
    final map = doc.data()!;
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return PassportToken(
      id: doc.id,
      memberId: (map['memberId'] ?? '') as String,
      memberName: (map['memberName'] ?? '') as String,
      civilite: (map['civilite'] ?? '') as String,
      grade: (map['grade'] ?? '') as String,
      initiationDate: (map['initiationDate'] ?? '') as String,
      entryDate: (map['entryDate'] ?? '') as String,
      lodgeName: (map['lodgeName'] ?? '') as String,
      lodgeNumber: (map['lodgeNumber'] ?? '') as String,
      lodgeOrient: (map['lodgeOrient'] ?? '') as String,
      lodgeObedience: (map['lodgeObedience'] ?? '') as String,
      createdAt: ts(map['createdAt']) ?? DateTime.now(),
      expiresAt: ts(map['expiresAt']) ?? DateTime.now(),
    );
  }

  // ─── Chrono (config/settings) ─────────────────────────────────
  /// Réserve et renvoie le chrono courant pour une nouvelle tenue, puis
  /// incrémente le compteur (comportement identique à getAndIncrementChrono
  /// côté React). Utilise une transaction pour éviter les doublons.
  Future<int> allocateSessionChrono() {
    final ref = _db.collection('config').doc('settings');
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? ((snap.data()?['regularSessionChrono'] ?? 1) as num).toInt()
          : 1;
      tx.set(ref, {'regularSessionChrono': current + 1},
          SetOptions(merge: true));
      return current;
    });
  }

  /// Réserve et renvoie le prochain numéro de Demande (Suggestions /
  /// Dysfonctionnements) pour la Loge courante, puis incrémente le compteur
  /// — même principe que [allocateSessionChrono]. Consigne au passage un log
  /// minimal (chrono + date + menu concerné), sans le texte de la demande :
  /// celui-ci ne vit que dans le PDF archivé sur Drive.
  Future<int> allocateRequestChrono(String menu) {
    final ref = _db.collection('config').doc('settings');
    final logRef = _db.collection('supportRequests').doc();
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? ((snap.data()?['requestChrono'] ?? 1) as num).toInt()
          : 1;
      tx.set(ref, {'requestChrono': current + 1}, SetOptions(merge: true));
      tx.set(logRef, {
        'chrono': current,
        'date': DateTime.now().toIso8601String(),
        'menu': menu,
      });
      return current;
    });
  }

  // ─── Accès Drive par fonction (config/settings) ─────────────────
  /// Dossiers Drive à synchroniser, avec les fonctions autorisées sur chacun
  /// — voir DriveAccessFolder. Vide tant que la Loge n'a pas été configurée.
  Future<List<DriveAccessFolder>> getDriveAccessFolders() async {
    final snap = await _db.collection('config').doc('settings').get();
    final raw = snap.data()?['driveAccessFolders'];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          DriveAccessFolder.fromMap(Map<String, dynamic>.from(entry)),
    ];
  }

  /// Dernier état connu des accès accordés par la synchronisation :
  /// dossier → (email → identifiant de permission Drive). Sert à ne
  /// retirer que les accès accordés PAR la synchronisation elle-même,
  /// jamais un partage ajouté manuellement pour une autre raison.
  Future<Map<String, Map<String, String>>> getDriveAccessGrants() async {
    final snap = await _db.collection('config').doc('settings').get();
    final raw = snap.data()?['driveAccessGrants'];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): Map<String, String>.from(
            (entry.value as Map).map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            ),
          ),
    };
  }

  Future<void> setDriveAccessGrants(
    Map<String, Map<String, String>> grants,
  ) {
    final ref = _db.collection('config').doc('settings');
    return ref.set({'driveAccessGrants': grants}, SetOptions(merge: true));
  }
}
