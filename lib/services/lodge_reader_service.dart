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

import '../config/lodge_config.dart';
import '../firebase_options_alkhemia.dart' as alkhemia;
import '../firebase_options_benoure.dart' as benoure;
import '../firebase_options_petitprince.dart' as petitprince;
import '../firebase_options_templehorus.dart' as templehorus;
import '../models/dignitary.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../models/member_event.dart';
import '../models/session.dart';
import '../models/visitor.dart';

/// Une des quatre loges, du point de vue de la lecture croisée Grande Loge.
class LodgeReaderTarget {
  final String key;
  final String label;
  final FirebaseOptions options;
  final String readerEmail;

  /// Logo de la loge (même asset que celui de son propre flavor, voir
  /// LodgeConfig), pour l'afficher sur les pavés Grande Loge.
  final String logoAsset;

  /// Configuration par défaut (compilée) de cette loge — sert de base à
  /// [LodgeReaderService.lodgeConfigOf], qui la fusionne avec son document
  /// `config/settings` réel (nom, dossiers Drive de bibliothèque...), exactement
  /// comme `LodgeConfig.forCurrentFlavor.mergedWith(...)` le fait pour la
  /// loge elle-même (voir firestore_repository.dart:lodgeConfigStream).
  final LodgeConfig baseConfig;
  const LodgeReaderTarget({
    required this.key,
    required this.label,
    required this.options,
    required this.readerEmail,
    required this.logoAsset,
    required this.baseConfig,
  });
}

// Mot de passe partagé des 4 comptes techniques « lecture-grandeloge@... » —
// forcément embarqué dans l'appli puisqu'elle s'y connecte elle-même, sans
// saisie humaine (limite connue de l'approche « compte partagé », acceptée
// à la conception : l'accès reste en lecture seule quoi qu'il arrive).
const String _readerPassword = 'GLDB-lecture-grandeloge-2026!';

const List<LodgeReaderTarget> kLodgeReaderTargets = [
  LodgeReaderTarget(
    key: 'alkhemia',
    label: 'AL-KHEMIA',
    options: alkhemia.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@alkhemia.gldb.placeholder',
    logoAsset: 'assets/Al-Khemia.png',
    baseConfig: LodgeConfig.alKhemia,
  ),
  LodgeReaderTarget(
    key: 'petitprince',
    label: 'Le Petit Prince',
    options: petitprince.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@petitprince.gldb.placeholder',
    logoAsset: 'assets/Petit-Prince.png',
    baseConfig: LodgeConfig.petitPrince,
  ),
  LodgeReaderTarget(
    key: 'templehorus',
    label: "Le Temple d'Horus",
    options: templehorus.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@templehorus.gldb.placeholder',
    logoAsset: 'assets/Temple-Horus.png',
    baseConfig: LodgeConfig.templeHorus,
  ),
  LodgeReaderTarget(
    key: 'benoure',
    label: 'Bénou Ré',
    options: benoure.DefaultFirebaseOptions.web,
    readerEmail: 'lecture-grandeloge@benoure.gldb.placeholder',
    logoAsset: 'assets/Benou-Re.png',
    baseConfig: LodgeConfig.benouRe,
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

  /// Fiches complètes des membres de [target], triées par nom — pour
  /// l'écran de consultation détaillée. Inclut hautsGradesDegree : c'est
  /// justement pour la Grande Loge que ce champ existe (voir Member.
  /// hautsGradesDegree) ; la restriction « admin seul » ne s'applique qu'à
  /// l'affichage côté loge bleue, pas ici.
  Future<List<Member>> membersOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('members').get();
    final members = [
      for (final doc in snap.docs) Member.fromMap(doc.id, doc.data()),
    ];
    members.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return members;
  }

  /// Tenues de [target], les plus récentes en premier — même règle Firestore
  /// que les fiches membres (`allow read: if signedIn()`, voir
  /// firestore.rules), donc pas de règle à modifier côté loges bleues pour
  /// cette lecture croisée.
  Future<List<Session>> sessionsOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('sessions').get();
    final sessions = [
      for (final doc in snap.docs) Session.fromMap(doc.id, doc.data()),
    ];
    sessions.sort((a, b) {
      final da = a.dateTime;
      final dbb = b.dateTime;
      if (da == null && dbb == null) return 0;
      if (da == null) return 1;
      if (dbb == null) return -1;
      return dbb.compareTo(da);
    });
    return sessions;
  }

  /// Tenues extérieures reçues par [target], les plus récentes en premier.
  Future<List<ExternalSession>> externalSessionsOf(
    LodgeReaderTarget target,
  ) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('externalSessions').get();
    final sessions = [
      for (final doc in snap.docs) ExternalSession.fromMap(doc.id, doc.data()),
    ];
    sessions.sort((a, b) {
      final da = a.dateTime;
      final dbb = b.dateTime;
      if (da == null && dbb == null) return 0;
      if (da == null) return 1;
      if (dbb == null) return -1;
      return dbb.compareTo(da);
    });
    return sessions;
  }

  /// Répertoire des visiteurs de [target], trié par nom.
  Future<List<Visitor>> visitorsOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('visitors').get();
    final visitors = [
      for (final doc in snap.docs) Visitor.fromMap(doc.id, doc.data()),
    ];
    visitors.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return visitors;
  }

  /// Répertoire des dignitaires de [target], trié par nom.
  Future<List<Dignitary>> dignitariesOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('dignitaries').get();
    final dignitaries = [
      for (final doc in snap.docs) Dignitary.fromMap(doc.id, doc.data()),
    ];
    dignitaries.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return dignitaries;
  }

  /// Historique des membres (élévations, changements de statut) de [target] —
  /// nécessaire au rapport d'activité (voir buildActivityReportPdf), sans
  /// écran de consultation dédié.
  Future<List<MemberEvent>> memberEventsOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('memberEvents').get();
    return [
      for (final doc in snap.docs) MemberEvent.fromMap(doc.id, doc.data()),
    ];
  }

  /// Configuration réelle de [target] (nom, dossiers Drive de bibliothèque...) :
  /// la base compilée ([LodgeReaderTarget.baseConfig]) fusionnée avec son
  /// document `config/settings`, exactement comme la loge le fait pour
  /// elle-même (voir firestore_repository.dart:lodgeConfigStream). Nécessaire
  /// car `templeHorus`/`alKhemia` n'ont pas encore de dossiers renseignés
  /// dans leur config compilée par défaut — seul Firestore a la valeur réelle.
  Future<LodgeConfig> lodgeConfigOf(LodgeReaderTarget target) async {
    final db = await _firestoreFor(target);
    final snap = await db.collection('config').doc('settings').get();
    final data = snap.data();
    if (data == null) return target.baseConfig;
    return target.baseConfig.mergedWith(data);
  }
}
