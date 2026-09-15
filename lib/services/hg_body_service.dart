// Accès Firestore pour les corps de Hauts Grades (IAH-MES, MAA-Kherou) —
// contrairement à lodge_reader_service.dart (lecture croisée vers un AUTRE
// projet Firebase), ceci lit/écrit dans le projet grande-loge-bourbon lui
// même : l'officier Grande Loge est déjà connecté dessus, pas besoin d'app
// Firebase secondaire ni de compte technique.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../models/member.dart';
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

  Stream<List<HgSession>> sessionsStream(HgBody body) {
    return _sessions(body).snapshots().map((snap) {
      final sessions = [
        for (final doc in snap.docs) HgSession.fromMap(doc.id, doc.data()),
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

  Future<void> saveSession(HgBody body, HgSession session) async {
    final data = session.toMap();
    if (session.id.isEmpty) {
      await _sessions(body).add(data);
    } else {
      await _sessions(body).doc(session.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteSession(HgBody body, String sessionId) {
    return _sessions(body).doc(sessionId).delete();
  }

  /// Numéro de convocation de [body], incrémenté à chaque génération — même
  /// mécanique que allocateRequestChrono (firestore_repository.dart),
  /// stocké dans config/settings sous une clé propre au corps.
  Future<int> allocateConvocationChrono(HgBody body) {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('config').doc('settings');
    final field = '${body.key}ConvocationChrono';
    return db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final current = snap.exists
          ? ((snap.data()?[field] ?? 1) as num).toInt()
          : 1;
      tx.set(ref, {field: current + 1}, SetOptions(merge: true));
      return current;
    });
  }
}
