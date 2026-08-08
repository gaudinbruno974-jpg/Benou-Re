// État global de l'application (porté depuis la logique de src/App.tsx).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

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
  }

  void _stopDataStreams() {
    _membersSub?.cancel();
    _sessionsSub?.cancel();
    _visitorsSub?.cancel();
    _vmNameSub?.cancel();
    _membersSub = null;
    _sessionsSub = null;
    _visitorsSub = null;
    _vmNameSub = null;
    members = [];
    sessions = [];
    visitors = [];
    lodgeVmName = '';
  }

  void _onStreamError(Object error) {
    dataError = error.toString();
    notifyListeners();
  }


  void _matchCurrentUser() {
    final email = _firebaseUser?.email?.toLowerCase();
    if (email == null) return;
    for (final m in members) {
      if (m.email.toLowerCase() == email) {
        currentUser = m;
        return;
      }
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
