// Accès Firestore pour les corps de Hauts Grades (IAH-MES, MAA-Kherou) —
// contrairement à lodge_reader_service.dart (lecture croisée vers un AUTRE
// projet Firebase), ceci lit/écrit dans le projet grande-loge-bourbon lui
// même : l'officier Grande Loge est déjà connecté dessus, pas besoin d'app
// Firebase secondaire ni de compte technique.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hg_body.dart';
import '../models/member.dart';

class HgBodyService {
  HgBodyService._();
  static final HgBodyService instance = HgBodyService._();

  CollectionReference<Map<String, dynamic>> _members(HgBody body) =>
      FirebaseFirestore.instance.collection(body.membersCollection);

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
}
