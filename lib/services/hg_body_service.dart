// Accès Firestore pour les corps de Hauts Grades (IAH-MES, MAA-Kherou) —
// contrairement à lodge_reader_service.dart (lecture croisée vers un AUTRE
// projet Firebase), ceci lit/écrit dans le projet grande-loge-bourbon lui
// même : l'officier Grande Loge est déjà connecté dessus, pas besoin d'app
// Firebase secondaire ni de compte technique.
//
// Les tenues réutilisent le modèle Session des loges bleues tel quel (même
// mécanique complète : ordre du jour libre, agapes, présences, émargement,
// planche tracée — demande explicite de l'utilisateur, « copie
// l'intégralité »), simplement stockées dans les collections dédiées du
// corps plutôt que dans `sessions`.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_presence_link.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';

class HgBodyService {
  HgBodyService._();
  static final HgBodyService instance = HgBodyService._();

  CollectionReference<Map<String, dynamic>> _members(HgBody body) =>
      FirebaseFirestore.instance.collection(body.membersCollection);

  CollectionReference<Map<String, dynamic>> _sessions(HgBody body) =>
      FirebaseFirestore.instance.collection(body.sessionsCollection);

  CollectionReference<Map<String, dynamic>> _visitors(HgBody body) =>
      FirebaseFirestore.instance.collection(body.visitorsCollection);

  CollectionReference<Map<String, dynamic>> _dignitaries(HgBody body) =>
      FirebaseFirestore.instance.collection(body.dignitariesCollection);

  Stream<List<Member>> membersStream(HgBody body) {
    return _members(body).snapshots().map((snap) {
      final members = [
        for (final doc in snap.docs) Member.fromMap(doc.id, doc.data()),
      ];
      members.sort(
        (a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      );
      return members;
    });
  }

  Future<List<Member>> membersOnce(HgBody body) => membersStream(body).first;

  Future<void> saveMember(HgBody body, Member member) async {
    final data = member.toMap()..remove('id');
    if (member.id.isEmpty) {
      await _members(body).add(data);
    } else {
      await _members(body).doc(member.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteMember(HgBody body, String memberId) {
    return _members(body).doc(memberId).delete();
  }

  Stream<List<Visitor>> visitorsStream(HgBody body) {
    return _visitors(body).snapshots().map((snap) {
      final visitors = [
        for (final doc in snap.docs) Visitor.fromMap(doc.id, doc.data()),
      ];
      visitors.sort(
        (a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      );
      return visitors;
    });
  }

  Future<void> saveVisitor(HgBody body, Visitor visitor) async {
    final data = visitor.toMap()..remove('id');
    if (visitor.id.isEmpty) {
      await _visitors(body).add(data);
    } else {
      await _visitors(body).doc(visitor.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteVisitor(HgBody body, String visitorId) {
    return _visitors(body).doc(visitorId).delete();
  }

  Stream<List<Dignitary>> dignitariesStream(HgBody body) {
    return _dignitaries(body).snapshots().map((snap) {
      final dignitaries = [
        for (final doc in snap.docs) Dignitary.fromMap(doc.id, doc.data()),
      ];
      dignitaries.sort(
        (a, b) => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      );
      return dignitaries;
    });
  }

  Future<void> saveDignitary(HgBody body, Dignitary dignitary) async {
    final data = dignitary.toMap()..remove('id');
    if (dignitary.id.isEmpty) {
      await _dignitaries(body).add(data);
    } else {
      await _dignitaries(
        body,
      ).doc(dignitary.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteDignitary(HgBody body, String dignitaryId) {
    return _dignitaries(body).doc(dignitaryId).delete();
  }

  Stream<List<Session>> sessionsStream(HgBody body) {
    return _sessions(body).snapshots().map((snap) {
      final sessions = [
        for (final doc in snap.docs) Session.fromMap(doc.id, doc.data()),
      ];
      sessions.sort((a, b) {
        final da = a.dateTime;
        final db_ = b.dateTime;
        if (da == null && db_ == null) return 0;
        if (da == null) return 1;
        if (db_ == null) return -1;
        return db_.compareTo(da);
      });
      return sessions;
    });
  }

  Future<void> addSession(HgBody body, Session session) {
    return _sessions(body).doc(session.id).set(session.toMap());
  }

  Future<void> updateSession(HgBody body, Session session) {
    return _sessions(body).doc(session.id).set(session.toMap());
  }

  Future<void> deleteSession(HgBody body, String sessionId) {
    return _sessions(body).doc(sessionId).delete();
  }

  Future<Session?> getSession(HgBody body, String sessionId) async {
    final doc = await _sessions(body).doc(sessionId).get();
    if (!doc.exists) return null;
    return Session.fromMap(doc.id, doc.data()!);
  }

  /// Numéro de tenue de [body], incrémenté à chaque création — même
  /// mécanique que allocateSessionChrono (firestore_repository.dart),
  /// stocké dans config/settings sous une clé propre au corps pour ne pas
  /// entrer en collision avec les autres compteurs (ni celui des loges
  /// bleues, ni celui d'un autre corps).
  Future<int> allocateSessionChrono(HgBody body) {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('config').doc('settings');
    final field = '${body.key}SessionChrono';
    return db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? ((snap.data()?[field] ?? 1) as num).toInt()
          : 1;
      tx.set(ref, {field: current + 1}, SetOptions(merge: true));
      return current;
    });
  }

  // ─── Liens de réponse individuels (collecte de présence sans connexion) ─
  // Une seule collection partagée par les deux corps — voir
  // models/hg_presence_link.dart pour le choix d'architecture.
  CollectionReference<Map<String, dynamic>> get _hgPresenceLinks =>
      FirebaseFirestore.instance.collection('hgPresenceLinks');

  HgPresenceLink _fromDoc(String id, Map<String, dynamic> map) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return HgPresenceLink(
      id: id,
      bodyKey: (map['bodyKey'] ?? '') as String,
      kind: (map['kind'] ?? kHgPresenceLinkKindMember) as String,
      sessionId: (map['sessionId'] ?? '') as String,
      sessionLabel: (map['sessionLabel'] ?? '') as String,
      sessionDateLabel: (map['sessionDateLabel'] ?? '') as String,
      sessionType: (map['sessionType'] ?? '') as String,
      sessionDegreeLabel: (map['sessionDegreeLabel'] ?? '') as String,
      hasAgape: (map['hasAgape'] ?? false) as bool,
      memberId: (map['memberId'] ?? '') as String,
      memberName: (map['memberName'] ?? '') as String,
      status: (map['status'] ?? kHgPresenceStatusPending) as String,
      agapePresent: map['agapePresent'] as bool?,
      recipientId: (map['recipientId'] ?? '') as String,
      recipientName: (map['recipientName'] ?? '') as String,
      delegationCount: (map['delegationCount'] as num?)?.toInt(),
      recipientAgapePresent: map['recipientAgapePresent'] as bool?,
      recipientAlone: (map['recipientAlone'] ?? false) as bool,
      respondedAt: ts(map['respondedAt']),
      expiresAt: ts(map['expiresAt']) ?? DateTime.now(),
      createdAt: ts(map['createdAt']) ?? DateTime.now(),
      applied: (map['applied'] ?? false) as bool,
    );
  }

  Map<String, dynamic> _toDoc(HgPresenceLink link) {
    return {
      'bodyKey': link.bodyKey,
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
      if (link.delegationCount != null) 'delegationCount': link.delegationCount,
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

  Future<void> createHgPresenceLink(HgPresenceLink link) {
    return _hgPresenceLinks.doc(link.id).set(_toDoc(link));
  }

  Stream<List<HgPresenceLink>> hgPresenceLinksForSessionStream(
    HgBody body,
    String sessionId,
  ) {
    return _hgPresenceLinks
        .where('bodyKey', isEqualTo: body.key)
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snap) => [for (final d in snap.docs) _fromDoc(d.id, d.data())]);
  }

  /// Lecture publique d'un jeton précis — seul accès autorisé par les règles
  /// à un visiteur non connecté (voir firestore.rules : `allow get`, jamais
  /// `allow list`).
  Future<HgPresenceLink?> getHgPresenceLink(String token) async {
    final doc = await _hgPresenceLinks.doc(token).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  /// Écriture publique de la réponse d'un membre (Flux A) — les règles
  /// Firestore limitent cette mise à jour aux seuls champs autorisés, avant
  /// expiration du jeton. `applied` est remis à `false` : une réponse
  /// modifiée après la première doit être reprise par le flux d'application
  /// automatique (voir AppState._applyHgPresenceLinks).
  Future<void> submitHgMemberResponse(
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
    return _hgPresenceLinks.doc(token).update(data);
  }

  /// Écriture publique de la réponse d'un dignitaire (Flux B) : sa propre
  /// présence, plus le décompte de sa délégation (sans objet s'il vient
  /// seul — voir recipientAlone).
  Future<void> submitHgDelegationResponse(
    String token, {
    required String status,
    int? delegationCount,
    bool? recipientAgapePresent,
  }) {
    final data = <String, dynamic>{
      'status': status,
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'applied': false,
    };
    if (delegationCount != null) data['delegationCount'] = delegationCount;
    if (recipientAgapePresent != null) {
      data['recipientAgapePresent'] = recipientAgapePresent;
    }
    return _hgPresenceLinks.doc(token).update(data);
  }

  Future<void> syncHgPresenceLinkRecipientAlone(String token, bool alone) {
    return _hgPresenceLinks.doc(token).update({'recipientAlone': alone});
  }

  /// Liens non encore répercutés dans une tenue — voir
  /// AppState._applyHgPresenceLinks, souscrit uniquement pour un utilisateur
  /// habilité à éditer au moins un des deux corps (canEditHgBody).
  Stream<List<HgPresenceLink>> unappliedHgPresenceLinksStream() {
    return _hgPresenceLinks
        .where('applied', isEqualTo: false)
        .snapshots()
        .map((snap) => [for (final d in snap.docs) _fromDoc(d.id, d.data())]);
  }

  Future<void> markHgPresenceLinkApplied(String token) {
    return _hgPresenceLinks.doc(token).update({'applied': true});
  }
}
