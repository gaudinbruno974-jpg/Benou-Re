// Lecture croisée, en lecture seule, vers les quatre loges — depuis le
// flavor Grande Loge uniquement. Un seul compte technique partagé par loge
// (pas un par officier Grande Loge, voir discussion de conception) : chaque
// loge a créé un compte « lecture-grandeloge@... » dont les règles
// Firestore interdisent toute écriture (vérifié en conditions réelles à la
// création — lecture 200, écriture 403 sur une fiche tierce).
//
// Même principe d'app Firebase secondaire que member_account_service.dart /
// drive_service.dart : une app nommée par loge, pour ne jamais remplacer la
// session de l'officier Grande Loge connecté sur l'app principale.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options_alkhemia.dart' as alkhemia;
import '../firebase_options_benoure.dart' as benoure;
import '../firebase_options_petitprince.dart' as petitprince;
import '../firebase_options_templehorus.dart' as templehorus;

/// Une des quatre loges, du point de vue de la lecture croisée Grande Loge.
class LodgeReaderTarget {
  final String key;
  final String label;
  final FirebaseOptions options;
  final String readerEmail;
  const LodgeReaderTarget({
    required this.key,
    required this.label,
    required this.options,
    required this.readerEmail,
  });
}

// Mot de passe partagé des 4 comptes techniques « lecture-grandeloge@... » —
// forcément embarqué dans l'appli puisqu'elle s'y connecte elle-même, sans
// saisie humaine (limite connue de l'approche « compte partagé », acceptée
// à la conception : l'accès reste en lecture seule quoi qu'il arrive).
const String _readerPassword = 'GLDB-lecture-grandeloge-2026!';

const List<LodgeReaderTarget> kLodgeReaderTargets = [
  LodgeReaderTarget(
    key: 'benoure',
    label: 'Bénou Ré',
    options: benoure.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@benoure.gldb.placeholder',
  ),
  LodgeReaderTarget(
    key: 'petitprince',
    label: 'Le Petit Prince',
    options: petitprince.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@petitprince.gldb.placeholder',
  ),
  LodgeReaderTarget(
    key: 'templehorus',
    label: "Le Temple d'Horus",
    options: templehorus.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@templehorus.gldb.placeholder',
  ),
  LodgeReaderTarget(
    key: 'alkhemia',
    label: 'AL-KHEMIA',
    options: alkhemia.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@alkhemia.gldb.placeholder',
  ),
];

class LodgeReaderService {
  LodgeReaderService._();
  static final LodgeReaderService instance = LodgeReaderService._();

  final Map<String, FirebaseApp> _apps = {};

  Future<FirebaseApp> _appFor(LodgeReaderTarget target) async {
    final existing = _apps[target.key];
    if (existing != null) return existing;
    final name = 'reader_${target.key}';
    FirebaseApp app;
    try {
      app = Firebase.app(name);
    } on FirebaseException {
      app = await Firebase.initializeApp(name: name, options: target.options);
    }
    _apps[target.key] = app;
    return app;
  }

  Future<FirebaseFirestore> _firestoreFor(LodgeReaderTarget target) async {
    final app = await _appFor(target);
    final auth = FirebaseAuth.instanceFor(app: app);
    if (auth.currentUser == null) {
      await auth.signInWithEmailAndPassword(
        email: target.readerEmail,
        password: _readerPassword,
      );
    }
    return FirebaseFirestore.instanceFor(app: app);
  }

  /// Nombre de membres actifs sur [target] — sonde minimale pour vérifier la
  /// connexion croisée depuis l'appli elle-même. Pas encore d'écran de
  /// consultation détaillée (étape suivante).
  Future<int> memberCount(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db
        .collection('members')
        .where('status', isEqualTo: 'Actif')
        .count()
        .get();
    return snap.count ?? 0;
  }
}
