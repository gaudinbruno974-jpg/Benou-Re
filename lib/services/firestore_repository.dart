// Accès Firestore (porté depuis src/lib/firebaseSync.ts).
// Collections : members, sessions, visitors, dignitaries, config.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/inventory_check.dart';
import '../models/inventory_item.dart';
import '../models/member.dart';
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

  // ─── Liens de réponse individuels (collecte de présence sans connexion,
  // Flux A — membres de la Loge) ──────────────────────────────────
  PresenceLink _presenceLinkFromDoc(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return PresenceLink(
      id: id,
      sessionId: (map['sessionId'] ?? '') as String,
      memberId: (map['memberId'] ?? '') as String,
      memberName: (map['memberName'] ?? '') as String,
      sessionLabel: (map['sessionLabel'] ?? '') as String,
      sessionDateLabel: (map['sessionDateLabel'] ?? '') as String,
      sessionType: (map['sessionType'] ?? '') as String,
      sessionDegreeLabel: (map['sessionDegreeLabel'] ?? '') as String,
      hasAgape: (map['hasAgape'] ?? false) as bool,
      status: (map['status'] ?? kPresenceStatusPending) as String,
      agapePresent: map['agapePresent'] as bool?,
      respondedAt: ts(map['respondedAt']),
      expiresAt: ts(map['expiresAt']) ?? DateTime.now(),
      createdAt: ts(map['createdAt']) ?? DateTime.now(),
      applied: (map['applied'] ?? false) as bool,
    );
  }

  Map<String, dynamic> _presenceLinkToDoc(PresenceLink link) {
    return {
      'sessionId': link.sessionId,
      'memberId': link.memberId,
      'memberName': link.memberName,
      'sessionLabel': link.sessionLabel,
      'sessionDateLabel': link.sessionDateLabel,
      'sessionType': link.sessionType,
      'sessionDegreeLabel': link.sessionDegreeLabel,
      'hasAgape': link.hasAgape,
      'status': link.status,
      if (link.agapePresent != null) 'agapePresent': link.agapePresent,
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
  /// mise à jour aux seuls champs `status` / `agapePresent` / `respondedAt`,
  /// et uniquement avant expiration du jeton.
  Future<void> submitPresenceResponse(
    String token, {
    required String status,
    bool? agapePresent,
  }) {
    final data = <String, dynamic>{
      'status': status,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
    };
    if (agapePresent != null) data['agapePresent'] = agapePresent;
    return _db.collection('presenceLinks').doc(token).update(data);
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
  /// concernée (voir AppState, qui applique puis marque `applied`).
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
}
