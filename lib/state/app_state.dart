// État global de l'application (porté depuis la logique de src/App.tsx).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/external_session.dart';
import '../models/inventory_check.dart';
import '../models/inventory_item.dart';
import '../models/member.dart';
import '../models/member_event.dart';
import '../models/passport_token.dart';
import '../models/presence_link.dart';
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
  List<Dignitary> dignitaries = [];
  List<InventoryItem> inventoryItems = [];
  List<InventoryCheck> inventoryChecks = [];
  List<ExternalSession> externalSessions = [];
  List<MemberEvent> memberEvents = [];
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
  StreamSubscription? _dignitariesSub;
  StreamSubscription? _inventoryItemsSub;
  StreamSubscription? _inventoryChecksSub;
  StreamSubscription? _externalSessionsSub;
  StreamSubscription? _memberEventsSub;
  StreamSubscription? _vmNameSub;
  StreamSubscription? _lodgeConfigSub;
  StreamSubscription? _presenceLinksSub;
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
    _dignitariesSub = repo.dignitariesStream().listen(
      (data) {
        dignitaries = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _inventoryItemsSub = repo.inventoryItemsStream().listen(
      (data) {
        inventoryItems = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _inventoryChecksSub = repo.inventoryChecksStream().listen(
      (data) {
        inventoryChecks = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _externalSessionsSub = repo.externalSessionsStream().listen(
      (data) {
        externalSessions = data;
        notifyListeners();
      },
      onError: _onStreamError,
    );
    _memberEventsSub = repo.memberEventsStream().listen(
      (data) {
        memberEvents = data;
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
    _dignitariesSub?.cancel();
    _inventoryItemsSub?.cancel();
    _inventoryChecksSub?.cancel();
    _externalSessionsSub?.cancel();
    _memberEventsSub?.cancel();
    _vmNameSub?.cancel();
    _lodgeConfigSub?.cancel();
    _presenceLinksSub?.cancel();
    _membersSub = null;
    _sessionsSub = null;
    _visitorsSub = null;
    _dignitariesSub = null;
    _inventoryItemsSub = null;
    _inventoryChecksSub = null;
    _externalSessionsSub = null;
    _memberEventsSub = null;
    _vmNameSub = null;
    _lodgeConfigSub = null;
    _presenceLinksSub = null;
    members = [];
    sessions = [];
    visitors = [];
    dignitaries = [];
    inventoryItems = [];
    inventoryChecks = [];
    externalSessions = [];
    memberEvents = [];
    lodgeVmName = '';
    // Retour au repli du flavor : l'écran de connexion doit afficher l'identité
    // de la Loge sans dépendre d'une session ouverte.
    LodgeConfig.current = LodgeConfig.forCurrentFlavor;
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
    if (user == null) {
      _syncPresenceLinksIfNeeded();
      return;
    }
    final uid = user.uid;
    for (final m in members) {
      if (m.authUid == uid) {
        currentUser = m;
        _syncPresenceLinksIfNeeded();
        return;
      }
    }
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      _syncPresenceLinksIfNeeded();
      return;
    }
    for (final m in members) {
      if (m.authUid.isNotEmpty) continue;
      if (m.effectiveLoginEmail.toLowerCase() != email) continue;
      currentUser = m;
      unawaited(_attachAuthUid(m, uid));
      _syncPresenceLinksIfNeeded();
      return;
    }
    _syncPresenceLinksIfNeeded();
  }

  /// Synchronisation automatique des réponses reçues par lien (collecte de
  /// présence sans connexion, Flux A) : démarre/arrête l'écoute selon que
  /// l'utilisateur connecté a le droit d'éditer les tenues, seul habilité par
  /// les règles Firestore à lister `presenceLinks` et à écrire dans
  /// `sessions`.
  void _syncPresenceLinksIfNeeded() {
    final allowed = canEditSessions(currentUser);
    if (allowed && _presenceLinksSub == null) {
      _presenceLinksSub = repo.unappliedPresenceLinksStream().listen(
        _applyPresenceLinks,
        onError: (_) {},
      );
    } else if (!allowed && _presenceLinksSub != null) {
      _presenceLinksSub?.cancel();
      _presenceLinksSub = null;
    }
  }

  /// Répercute chaque réponse reçue — Flux A (membre) dans
  /// `session.presentIds` / `excusedIds` / `agapeIds`, Flux B (dignitaire,
  /// qu'il vienne seul ou avec une délégation) dans `session.dignitaryIds` /
  /// `dignitaryAgapeIds`, Flux C (membre invité à une Tenue extérieure —
  /// voir external_session.dart) dans `externalSession.attendingMemberIds`
  /// — l'équivalent de ce que fait aujourd'hui le Secrétaire à la main dans
  /// « Présents en tenue » — puis marque le jeton `applied`. Relit la
  /// tenue/l'invitation juste avant chaque écriture (plutôt que de partir de
  /// [sessions]/[externalSessions], potentiellement périmés) pour rester
  /// correct si plusieurs réponses arrivent pour la même tenue dans un seul
  /// lot.
  Future<void> _applyPresenceLinks(List<PresenceLink> links) async {
    for (final link in links) {
      try {
        if (link.kind == kPresenceLinkKindExternal) {
          final external = await repo.getExternalSession(link.sessionId);
          if (external == null) {
            await repo.markPresenceLinkApplied(link.id);
            continue;
          }
          await repo.setExternalSession(applyExternalResponse(external, link));
          await repo.markPresenceLinkApplied(link.id);
          continue;
        }
        final session = await repo.getSession(link.sessionId);
        if (session == null) {
          await repo.markPresenceLinkApplied(link.id);
          continue;
        }
        final map = Map<String, dynamic>.from(session.toMap());
        if (link.kind == kPresenceLinkKindMember) {
          final present = List<String>.from(session.presentIds)
            ..remove(link.memberId);
          final excused = List<String>.from(session.excusedIds)
            ..remove(link.memberId);
          final agape = List<String>.from(session.agapeIds)
            ..remove(link.memberId);
          if (link.status == kPresenceStatusPresent) {
            present.add(link.memberId);
            if (link.agapePresent == true) agape.add(link.memberId);
          } else if (link.status == kPresenceStatusAbsent) {
            excused.add(link.memberId);
          }
          map['presentIds'] = present;
          map['excusedIds'] = excused;
          map['agapeIds'] = agape;
        } else {
          // Dignitaire (Flux B) : sa propre présence est toujours une
          // réponse nominative, qu'il vienne seul (rang 1/2 — agape dans
          // link.agapePresent, même champ qu'un membre) ou avec une
          // délégation (rang 3+ — agape dans link.recipientAgapePresent,
          // distincte du total agrégé de la délégation, jamais appliqué
          // automatiquement faute de fiches nommées). Sans liste « excusé »
          // dédiée : absent revient simplement à ne pas figurer dans
          // dignitaryIds.
          final present = List<String>.from(session.dignitaryIds)
            ..remove(link.recipientId);
          final agape = List<String>.from(session.dignitaryAgapeIds)
            ..remove(link.recipientId);
          if (link.status == kPresenceStatusPresent) {
            present.add(link.recipientId);
            final ownAgape =
                link.recipientAlone ? link.agapePresent : link.recipientAgapePresent;
            if (ownAgape == true) agape.add(link.recipientId);
          }
          map['dignitaryIds'] = present;
          map['dignitaryAgapeIds'] = agape;
        }
        await repo.setSession(Session.fromMap(session.id, map));
        await repo.markPresenceLinkApplied(link.id);
      } catch (_) {
        // Le jeton reste `applied = false` : une prochaine mise à jour du
        // flux retentera automatiquement l'application.
      }
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

  // Actions Demandes (Suggestions / Dysfonctionnements)
  Future<int> allocateRequestChrono(String menu) =>
      repo.allocateRequestChrono(menu);

  // Réglages de la Loge
  Future<void> updateLodgeVmName(String name) => repo.setLodgeVmName(name);

  // Actions inventaire du matériel
  Future<void> addInventoryItem(InventoryItem i) => repo.setInventoryItem(i);
  Future<void> updateInventoryItem(InventoryItem i) => repo.setInventoryItem(i);
  Future<void> deleteInventoryItem(String id) => repo.deleteInventoryItem(id);
  Future<void> submitInventoryCheck(InventoryCheck c) =>
      repo.addInventoryCheck(c);

  // Liens de réponse individuels (collecte de présence sans connexion)
  Future<void> createPresenceLink(PresenceLink link) =>
      repo.createPresenceLink(link);
  Stream<List<PresenceLink>> presenceLinksForSession(String sessionId) =>
      repo.presenceLinksForSessionStream(sessionId);
  Future<PresenceLink?> getPresenceLink(String token) =>
      repo.getPresenceLink(token);
  Future<void> submitPresenceResponse(
    String token, {
    required String status,
    bool? agapePresent,
  }) => repo.submitPresenceResponse(
    token,
    status: status,
    agapePresent: agapePresent,
  );
  Future<void> submitDelegationResponse(
    String token, {
    required String status,
    required int apprentiCount,
    required int compagnonCount,
    required int maitreCount,
    required int agapeTotal,
    bool? recipientAgapePresent,
  }) => repo.submitDelegationResponse(
    token,
    status: status,
    apprentiCount: apprentiCount,
    compagnonCount: compagnonCount,
    maitreCount: maitreCount,
    agapeTotal: agapeTotal,
    recipientAgapePresent: recipientAgapePresent,
  );
  Future<void> syncPresenceLinkRecipientAlone(String token, bool alone) =>
      repo.syncPresenceLinkRecipientAlone(token, alone);

  // Passeport Maçonnique (jeton de vérification à durée de vie courte)
  Future<void> createPassportToken(PassportToken token) =>
      repo.createPassportToken(token);
  Future<PassportToken?> getPassportToken(String token) =>
      repo.getPassportToken(token);

  // Actions visiteurs
  Future<void> addVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> updateVisitor(Visitor v) => repo.setVisitor(v);
  Future<void> deleteVisitor(String id) => repo.deleteVisitor(id);

  // Actions dignitaires
  Future<void> addDignitary(Dignitary d) => repo.setDignitary(d);
  Future<void> updateDignitary(Dignitary d) => repo.setDignitary(d);
  Future<void> deleteDignitary(String id) => repo.deleteDignitary(id);

  // Registre des Tenues extérieures
  Future<void> addExternalSession(ExternalSession s) =>
      repo.setExternalSession(s);
  Future<void> updateExternalSession(ExternalSession s) =>
      repo.setExternalSession(s);
  Future<void> deleteExternalSession(String id) =>
      repo.deleteExternalSession(id);

  /// Enregistre un événement d'historique (élévation de grade ou changement
  /// de statut) et met à jour le grade/statut courant du membre dans la
  /// même action — une seule saisie, jamais désynchronisée entre la fiche
  /// et l'historique.
  Future<void> logMemberEvent(Member member, MemberEvent event) async {
    await repo.setMemberEvent(event);
    final updated = event.type == kMemberEventElevation
        ? member.copyWith(grade: event.toValue)
        : member.copyWith(status: event.toValue);
    await repo.setMember(updated);
  }

  Future<void> deleteMemberEvent(String id) => repo.deleteMemberEvent(id);

  @override
  void dispose() {
    _stopDataStreams();
    _authSub.cancel();
    super.dispose();
  }
}
