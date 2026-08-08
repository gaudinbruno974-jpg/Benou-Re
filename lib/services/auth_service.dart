// Authentification Firebase (porté depuis src/lib/firebaseSync.ts -> loginWithFirebase).
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    // Les e-mails Firebase (mot de passe oublié, invitation) partent en
    // français quelle que soit la langue du navigateur ou du projet.
    _auth.setLanguageCode('fr');
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return cred.user!;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());

  Future<void> logout() => _auth.signOut();
}
