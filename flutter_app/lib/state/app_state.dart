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
  fb.User? _firebaseUser;

  late final StreamSubscription _membersSub;
  late final StreamSubscription _sessionsSub;
  late final StreamSubscription _visitorsSub;
  late final StreamSubscription _authSub;

  void _init() {
    _membersSub = repo.membersStream().listen((data) {
      members = data;
      _matchCurrentUser();
      notifyListeners();
    });
    _sessionsSub = repo.sessionsStream().listen((data) {
      sessions = data;
      notifyListeners();
    });
    _visitorsSub = repo.visitorsStream().listen((data) {
      visitors = data;
      notifyListeners();
    });
    _authSub = auth.authStateChanges().listen((user) {
      _firebaseUser = user;
      authLoading = false;
      if (user == null) currentUser = null;
      _matchCurrentUser();
      notifyListeners();
    });
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

  // Actions visiteurs
  Future<void> addVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> updateVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> deleteVisitor(String id) => repo.deleteVisitor(id);

  @override
  void dispose() {
    _membersSub.cancel();
    _sessionsSub.cancel();
    _visitorsSub.cancel();
    _authSub.cancel();
    super.dispose();
  }
}
