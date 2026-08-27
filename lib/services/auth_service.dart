// Authentification Firebase (porté depuis src/lib/firebaseSync.ts -> loginWithFirebase).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    // Les e-mails Firebase (mot de passe oublié, invitation) partent en
    // français quelle que soit la langue du navigateur ou du projet.
    _auth.setLanguageCode('fr');
    // Confidentialité : une Loge maçonnique ne doit jamais rester connectée
    // après fermeture complète du navigateur (poste partagé/public). Par
    // défaut Firebase Web persiste la session indéfiniment (LOCAL) ; on la
    // limite à la durée de vie de la fenêtre/l'onglet (SESSION) — la case
    // « Se souvenir de moi » de l'écran de connexion ne mémorise que
    // l'e-mail, jamais la session elle-même. Sans effet sur mobile/desktop
    // natif (persistance déjà gérée différemment par le SDK Firebase).
    if (kIsWeb) {
      _auth.setPersistence(Persistence.SESSION);
    }
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
