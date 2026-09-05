// Synchronisation des accès Drive selon la fonction des membres (V∴M∴,
// Secrétaire, Trésorier) — voir drive_access_sync_screen.dart. Remplace le
// partage manuel dossier par dossier : le V∴M∴ presse un bouton, l'app
// accorde les accès manquants et retire ceux devenus obsolètes.
//
// Seuls les accès que la synchronisation a elle-même accordés sont retirés
// (suivis dans config/settings.driveAccessGrants, par identifiant de
// permission Drive) — jamais un partage ajouté manuellement pour une autre
// raison, comme le compte propriétaire de l'arborescence.
import '../config/lodge_config.dart';
import '../models/drive_access_folder.dart';
import '../models/member.dart';
import '../models/session.dart';
import 'drive_service.dart';
import 'firestore_repository.dart';
import 'xlsx_codec.dart';

/// « Morceaux d'Architecture » plutôt que la simple clé technique
/// « Architecture » utilisée dans `config/settings.libraryFolders`.
const Map<String, String> _libraryCategoryLabels = {
  'Architecture': "Morceaux d'Architecture",
};

/// Un dossier de grade de la Bibliothèque, à plat — dérivé de
/// [LodgeConfig.libraryFolders] (catégorie -> grade -> id), pour être
/// synchronisé avec le même mécanisme que les dossiers du Bureau.
class _LibraryTarget {
  final String folderId;
  final String name;
  final int minGradeRank;
  const _LibraryTarget({
    required this.folderId,
    required this.name,
    required this.minGradeRank,
  });
}

List<_LibraryTarget> _libraryTargets(Map<String, Map<String, String>> libraryFolders) {
  final targets = <_LibraryTarget>[];
  for (final category in libraryFolders.entries) {
    for (final grade in category.value.entries) {
      final folderId = grade.value.trim();
      if (folderId.isEmpty) continue;
      targets.add(
        _LibraryTarget(
          folderId: folderId,
          name: 'Bibliothèque — '
              '${_libraryCategoryLabels[category.key] ?? category.key} — '
              '${grade.key}',
          minGradeRank: Session.degreeRank(grade.key),
        ),
      );
    }
  }
  return targets;
}

/// « V∴M∴ », « Secrétaire »… plutôt que les identifiants techniques
/// (venerable/secretaire/tresorier) utilisés en base.
const Map<String, String> _roleFolderLabels = {
  kRoleVenerable: 'V∴M∴',
  kRoleSecretaire: 'Secrétaire',
  kRoleTresorier: 'Trésorier',
};

const Map<String, String> _driveRoleLabels = {
  'owner': 'Propriétaire',
  'writer': 'Éditeur',
  'commenter': 'Commentateur',
  'reader': 'Lecteur',
};

const List<String> kDriveAccessReportHeaders = [
  'Dossier',
  'Rôles prévus',
  'Accès réels',
];

/// Classeur (1 feuille) listant, dossier par dossier, les rôles prévus et
/// les accès réellement constatés sur Drive — même contenu que la section
/// « Accès existants » de l'écran, archivé pour garder une trace datée.
List<int> buildDriveAccessReportWorkbook(List<FolderAccessSummary> access) {
  return buildXlsx({
    'Accès Drive': [
      kDriveAccessReportHeaders,
      for (final folder in access)
        [
          folder.folderName,
          folder.expectedRoles
              .map((r) => _roleFolderLabels[r] ?? r)
              .join(', '),
          folder.entries
              .map((e) => '${e.email} (${_driveRoleLabels[e.role] ?? e.role})')
              .join('; '),
        ],
    ],
  });
}

/// Fonctions autorisées d'un membre, déduites de son office — mêmes
/// critères textuels que member.dart (insensibles à la casse et aux
/// accents), mais SANS le contournement isAdmin : l'accès Drive suit la
/// fonction réelle, pas un simple indicateur technique.
List<String> driveRolesFor(Member member) {
  final fn = foldLabel(member.function);
  final roles = <String>[];
  if (fn.contains('venerable')) roles.add(kRoleVenerable);
  if (fn.contains('secretaire')) roles.add(kRoleSecretaire);
  if (fn.contains('tresorier')) roles.add(kRoleTresorier);
  return roles;
}

class DriveAccessSyncResult {
  final List<String> granted; // "email — dossier"
  final List<String> revoked; // "email — dossier"
  final List<String> failed; // "email — dossier : erreur"
  final List<String> driftCorrected; // "email — dossier"
  final List<String> roleFixed; // "email — dossier (ancien → nouveau)"
  const DriveAccessSyncResult({
    required this.granted,
    required this.revoked,
    required this.failed,
    required this.driftCorrected,
    required this.roleFixed,
  });

  bool get isEmpty =>
      granted.isEmpty &&
      revoked.isEmpty &&
      failed.isEmpty &&
      driftCorrected.isEmpty &&
      roleFixed.isEmpty;
}

/// Accès réels d'un dossier, lus en direct sur Drive (pas depuis le suivi
/// Firestore) — pour la section « Accès existants » de l'écran.
class FolderAccessSummary {
  final String folderName;
  final List<String> expectedRoles;
  final List<({String email, String role})> entries;
  const FolderAccessSummary({
    required this.folderName,
    required this.expectedRoles,
    required this.entries,
  });
}

class DriveAccessSyncService {
  DriveAccessSyncService({
    FirestoreRepository? repo,
    DriveService? drive,
  })  : _repo = repo ?? FirestoreRepository(),
        _drive = drive ?? DriveService.instance;

  final FirestoreRepository _repo;
  final DriveService _drive;

  Future<DriveAccessSyncResult> sync(List<Member> members) async {
    final folders = await _repo.getDriveAccessFolders();
    final grants = await _repo.getDriveAccessGrants();

    final granted = <String>[];
    final revoked = <String>[];
    final failed = <String>[];
    final driftCorrected = <String>[];
    final roleFixed = <String>[];

    for (final folder in folders) {
      final shouldHave = <String>{
        for (final m in members)
          if (m.email.trim().isNotEmpty &&
              driveRolesFor(m).any(folder.roles.contains))
            m.email.trim().toLowerCase(),
      };
      await _syncFolder(
        folderId: folder.folderId,
        name: folder.name,
        role: 'writer',
        shouldHave: shouldHave,
        grants: grants,
        granted: granted,
        revoked: revoked,
        failed: failed,
        driftCorrected: driftCorrected,
        roleFixed: roleFixed,
      );
    }

    // Bibliothèque : ouverte à TOUS les membres (pas seulement le Bureau),
    // selon leur grade — un Apprenti n'a accès qu'au niveau Apprenti, un
    // Maître a accès aux trois niveaux, même logique que l'éligibilité aux
    // tenues (voir Session.degreeRank). En Lecteur seul : consulter les
    // planches/rituels/instructions, jamais les modifier — l'édition reste
    // réservée au V∴M∴ et au Secrétaire via les dossiers du Bureau
    // (07 Planches / 08 Rituel / 12 instruction, en Éditeur ci-dessus).
    for (final lib in _libraryTargets(LodgeConfig.current.libraryFolders)) {
      final shouldHave = <String>{
        for (final m in members)
          if (m.email.trim().isNotEmpty &&
              Session.degreeRank(m.grade) >= lib.minGradeRank)
            m.email.trim().toLowerCase(),
      };
      await _syncFolder(
        folderId: lib.folderId,
        name: lib.name,
        role: 'reader',
        shouldHave: shouldHave,
        grants: grants,
        granted: granted,
        revoked: revoked,
        failed: failed,
        driftCorrected: driftCorrected,
        roleFixed: roleFixed,
      );
    }

    await _repo.setDriveAccessGrants(grants);
    return DriveAccessSyncResult(
      granted: granted,
      revoked: revoked,
      failed: failed,
      driftCorrected: driftCorrected,
      roleFixed: roleFixed,
    );
  }

  /// Synchronise un seul dossier (Bureau ou Bibliothèque) : dérive, retraits
  /// puis ajouts, sur le même principe — factorisé pour être partagé par
  /// les deux catégories de dossiers dans [sync]. [role] est le rôle Drive
  /// attendu pour CE dossier (« writer » pour le Bureau, « reader » pour la
  /// Bibliothèque) : un accès déjà présent mais à un autre rôle (ex. un
  /// Éditeur accordé avant l'introduction du Lecteur) est corrigé sur place.
  Future<void> _syncFolder({
    required String folderId,
    required String name,
    required String role,
    required Set<String> shouldHave,
    required Map<String, Map<String, String>> grants,
    required List<String> granted,
    required List<String> revoked,
    required List<String> failed,
    required List<String> driftCorrected,
    required List<String> roleFixed,
  }) async {
    final current = Map<String, String>.from(grants[folderId] ?? {});

    // Dérive : une permission notée dans Firestore n'existe peut-être plus
    // réellement sur Drive (retirée à la main, appel précédent en échec
    // silencieux), ou existe mais avec un rôle différent de celui attendu.
    // Vérifié AVANT de décider quoi ajouter/retirer, pour ne jamais se fier
    // à un état périmé.
    for (final email in current.keys.toList()) {
      final permissionId = current[email]!;
      String? actualRole;
      try {
        actualRole = await _drive.permissionRole(
          folderId: folderId,
          permissionId: permissionId,
        );
      } catch (e) {
        failed.add('$email — $name (vérification) : $e');
        continue;
      }
      if (actualRole == null) {
        current.remove(email);
        driftCorrected.add('$email — $name');
      } else if (actualRole != role) {
        try {
          await _drive.updatePermissionRole(
            folderId: folderId,
            permissionId: permissionId,
            role: role,
          );
          roleFixed.add('$email — $name ($actualRole → $role)');
        } catch (e) {
          failed.add('$email — $name (correction du rôle) : $e');
        }
      }
    }

    // Retraits : accordé par une précédente synchronisation, mais plus
    // éligible aujourd'hui (fonction ou grade).
    for (final email in current.keys.toList()) {
      if (shouldHave.contains(email)) continue;
      final permissionId = current[email]!;
      try {
        await _drive.revokeFolderAccess(
          folderId: folderId,
          permissionId: permissionId,
        );
        current.remove(email);
        revoked.add('$email — $name');
      } catch (e) {
        failed.add('$email — $name (retrait) : $e');
      }
    }

    // Ajouts : éligible, pas encore d'accès.
    for (final email in shouldHave) {
      if (current.containsKey(email)) continue;
      try {
        final permissionId = await _drive.grantFolderAccess(
          folderId: folderId,
          email: email,
          role: role,
        );
        current[email] = permissionId;
        granted.add('$email — $name');
      } catch (e) {
        failed.add('$email — $name (ajout) : $e');
      }
    }

    grants[folderId] = current;
  }

  /// Photo des accès réels, dossier par dossier, lue en direct sur Drive —
  /// révèle aussi un partage ajouté à la main en dehors de cette
  /// synchronisation, ce que le suivi Firestore ne montrerait jamais.
  /// Couvre les dossiers du Bureau ET ceux de la Bibliothèque.
  Future<List<FolderAccessSummary>> currentAccess() async {
    final folders = await _repo.getDriveAccessFolders();
    final summaries = <FolderAccessSummary>[];
    for (final folder in folders) {
      final entries = await _drive.listFolderAccess(folderId: folder.folderId);
      summaries.add(
        FolderAccessSummary(
          folderName: folder.name,
          expectedRoles: folder.roles,
          entries: entries,
        ),
      );
    }
    for (final lib in _libraryTargets(LodgeConfig.current.libraryFolders)) {
      final entries = await _drive.listFolderAccess(folderId: lib.folderId);
      summaries.add(
        FolderAccessSummary(
          folderName: lib.name,
          expectedRoles: const ['Tous les membres du grade et au-dessus'],
          entries: entries,
        ),
      );
    }
    return summaries;
  }
}
