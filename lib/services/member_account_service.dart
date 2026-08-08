// Création du compte de connexion d'un membre.
//
// Un membre est d'abord une fiche Firestore ; sans compte Firebase Auth, il ne
// peut pas se connecter. La création passe par une application Firebase
// secondaire : sur l'instance principale, `createUserWithEmailAndPassword`
// connecterait aussitôt le nouveau compte et déconnecterait le Secrétaire.
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Résultat d'une demande d'invitation.
enum MemberAccountResult {
  /// Compte créé et e-mail de définition du mot de passe envoyé.
  created,

  /// Le compte existait déjà : e-mail de définition du mot de passe renvoyé.
  alreadyExists,
}

class MemberAccountService {
  MemberAccountService._();
  static final MemberAccountService instance = MemberAccountService._();

  static const String _appName = 'memberAdmin';

  /// Crée le compte de connexion de [email] si besoin, puis envoie l'e-mail
  /// permettant de définir le mot de passe.
  Future<MemberAccountResult> invite(String email) async {
    final address = email.trim().toLowerCase();
    if (address.isEmpty) {
      throw ArgumentError('Adresse e-mail vide.');
    }
    final auth = FirebaseAuth.instanceFor(app: await _adminApp());
    var result = MemberAccountResult.created;
    try {
      await auth.createUserWithEmailAndPassword(
        email: address,
        // Le membre ne connaît jamais ce mot de passe : il le définit par
        // l'e-mail qui suit.
        password: _throwawayPassword(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') rethrow;
      result = MemberAccountResult.alreadyExists;
    } finally {
      await auth.signOut();
    }
    await auth.sendPasswordResetEmail(email: address);
    return result;
  }

  /// Application Firebase dédiée, pour ne pas remplacer la session en cours.
  Future<FirebaseApp> _adminApp() async {
    try {
      return Firebase.app(_appName);
    } on FirebaseException {
      return Firebase.initializeApp(
        name: _appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  String _throwawayPassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
