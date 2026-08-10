// État global de l'application (porté depuis la logique de src/App.tsx).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../config/lodge_config.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/auth_service.dart';
import '../services/firestore_repository.dart';

class AppState extends ChangeNotifier {
  final AuthService auth;
  final FirestoreRepository repo;

  AppState({AuthService? authService, FirestoreRepository? repository})
      : auth = authService ?? AuthService(),
        repo = repository ?? FirestoreRepository() {
    _init();
  }

  bool authLoading = true;
  List<Member> members = [];
  List<Session> sessions = [];
  List<Visitor> visitors = [];
  Member? currentUser;

  /// Nom du V∴M∴ en charge, lu dans `config/settings`.
  String lodgeVmName = '';

  /// Dernière erreur de lecture Firestore (droits, réseau), affichée à l'écran.
  String? dataError;

  /// Vrai dès que Firebase Auth a authentifié quelqu'un, même si sa fiche
  /// membre n'a pas encore été retrouvée.
  bool get isSignedIn => _firebaseUser != null;
  fb.User? _firebaseUser;

  StreamSubscription? _membersSub;
  StreamSubscription? _sessionsSub;
  StreamSubscription? _visitorsSub;
  StreamSubscription? _vmNameSub;
  StreamSubscription? _lodgeConfigSub;
  late final StreamSubscription _authSub;

  void _init() {
    _authSub = auth.authStateChanges().listen((user) {
      _firebaseUser = user;
      authLoading = false;
      if (user == null) {
        currentUser = null;
        _stopDataStreams();
      } else {
        _startDataStreams();
      }
      _matchCurrentUser();
      notifyListeners();
    });
  }

  /// Les collections ne sont lisibles qu'authentifié : on ne s'y abonne qu'après
  /// la connexion, sinon les règles Firestore refusent l'écoute et celle-ci est
  /// définitivement interrompue.
  void _startDataStreams() {
    if (_membersSub != null) return;
    _membersSub = repo.membersStream().listen(
      (data) {
        members = data;
        _matchCurrentUser();
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _sessionsSub = repo.sessionsStream().listen(
      (data) {
        sessions = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _visitorsSub = repo.visitorsStream().listen(
      (data) {
        visitors = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _vmNameSub = repo.lodgeVmNameStream().listen(
      (name) {
        lodgeVmName = name;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    // L'identité de la Loge sert aussi hors widgets (génération des PDF,
    // dossiers Drive) : elle est publiée dans LodgeConfig.current plutôt que
    // portée par l'état.
    _lodgeConfigSub = repo.lodgeConfigStream().listen(
      (config) {
        LodgeConfig.current = config;
        notifyListeners();
      },
      onError: _onStreamError,
    );
  }

  void _stopDataStreams() {
    _membersSub?.cancel();
    _sessionsSub?.cancel();
    _visitorsSub?.cancel();
    _vmNameSub?.cancel();
    _lodgeConfigSub?.cancel();
    _membersSub = null;
    _sessionsSub = null;
    _visitorsSub = null;
    _vmNameSub = null;
    _lodgeConfigSub = null;
    members = [];
    sessions = [];
    visitors = [];
    lodgeVmName = '';
    // Retour au repli du flavor : l'écran de connexion doit afficher l'identité
    // de la Loge sans dépendre d'une session ouverte.
    LodgeConfig.current = LodgeConfig.benouRe;
  }

  void _onStreamError(Object error) {
    dataError = error.toString();
    notifyListeners();
  }


  /// Retrouve la fiche du compte connecté : par l'identifiant Firebase
  /// (stable), sinon par l'adresse de connexion pour les fiches pas encore
  /// rattachées, auxquelles on inscrit alors cet identifiant.
  void _matchCurrentUser() {
    final user = _firebaseUser;
    if (user == null) return;
    final uid = user.uid;
    for (final m in members) {
      if (m.authUid == uid) {
        currentUser = m;
        return;
      }
    }
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return;
    for (final m in members) {
      if (m.authUid.isNotEmpty) continue;
      if (m.effectiveLoginEmail.toLowerCase() != email) continue;
      currentUser = m;
      unawaited(_attachAuthUid(m, uid));
      return;
    }
  }

  Future<void> _attachAuthUid(Member member, String uid) async {
    try {
      await repo.setMember(member.copyWith(authUid: uid));
    } catch (_) {
      // Un membre sans droit d'écriture sur sa fiche reste utilisable :
      // le rattachement se fera à une prochaine occasion.
    }
  }

  Future<void> logout() async {
    await auth.logout();
    currentUser = null;
    _stopDataStreams();
    notifyListeners();
  }

  // Actions membres
  Future<void> addMember(Member m) => repo.setMember(m);
  Future<void> updateMember(Member m) => repo.setMember(m);
  Future<void> deleteMember(String id) => repo.deleteMember(id);

  // Actions tenues
  Future<void> addSession(Session s) => repo.setSession(s);
  Future<void> updateSession(Session s) => repo.setSession(s);
  Future<void> deleteSession(String id) => repo.deleteSession(id);
  Future<int> allocateSessionChrono() => repo.allocateSessionChrono();

  // Réglages de la Loge
  Future<void> updateLodgeVmName(String name) => repo.setLodgeVmName(name);

  // Actions visiteurs
  Future<void> addVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> updateVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> deleteVisitor(String id) => repo.deleteVisitor(id);

  @override
  void dispose() {
    _stopDataStreams();
    _authSub.cancel();
    super.dispose();
  }
}
