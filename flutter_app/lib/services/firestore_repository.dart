// Accès Firestore (porté depuis src/lib/firebaseSync.ts).
// Collections : members, sessions, visitors, config.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';
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

  // ─── Chrono (config/settings) ─────────────────────────────────
  Future<int> getSessionChrono() async {
    final ref = _db.collection('config').doc('settings');
    final snap = await ref.get();
    if (snap.exists) {
      return (snap.data()?['regularSessionChrono'] ?? 2) as int;
    }
    await ref.set({'regularSessionChrono': 2});
    return 2;
  }

  Future<int> incrementSessionChrono() async {
    final ref = _db.collection('config').doc('settings');
    final snap = await ref.get();
    int newVal = 3;
    if (snap.exists) {
      final current = (snap.data()?['regularSessionChrono'] ?? 2) as int;
      newVal = current + 1;
    }
    await ref.set({'regularSessionChrono': newVal}, SetOptions(merge: true));
    return newVal;
  }
}
