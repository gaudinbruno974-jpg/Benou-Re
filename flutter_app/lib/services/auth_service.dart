// Authentification Firebase (porté depuis src/lib/firebaseSync.ts -> loginWithFirebase).
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_repository.dart';
import '../models/member.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirestoreRepository _repo;

  AuthService({FirebaseAuth? auth, FirestoreRepository? repo})
      : _auth = auth ?? FirebaseAuth.instance,
        _repo = repo ?? FirestoreRepository();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Connexion avec repli sur la migration des comptes pré-enregistrés :
  /// si l'utilisateur n'existe pas encore dans Firebase Auth mais qu'un
  /// document `members` correspond à l'email avec le bon mot de passe, on crée
  /// automatiquement le compte Auth (comme sur le web).
  Future<User> login(String email, String password) async {
    var cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'vm@loge.com') {
      cleanEmail = 'gaudin.bruno974@gmail.com';
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException {
      // Repli : chercher un membre pré-enregistré dans Firestore.
      final matched = await _repo.findMemberByEmail(cleanEmail);
      if (matched != null && matched.password == password) {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        final newUser = cred.user!;
        final migrated = matched.copyWith(loginId: cleanEmail);
        // Réécrit le document avec l'UID Auth comme identifiant.
        await _repo.setMember(Member.fromMap(newUser.uid, migrated.toMap()));
        if (matched.id != newUser.uid) {
          await _repo.deleteMember(matched.id);
        }
        return newUser;
      }
      rethrow;
    }
  }

  Future<void> logout() => _auth.signOut();
}
