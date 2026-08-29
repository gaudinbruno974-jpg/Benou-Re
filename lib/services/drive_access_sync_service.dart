// Synchronisation des accès Drive selon la fonction des membres (V∴M∴,
// Secrétaire, Trésorier) — voir drive_access_sync_screen.dart. Remplace le
// partage manuel dossier par dossier : le V∴M∴ presse un bouton, l'app
// accorde les accès manquants et retire ceux devenus obsolètes.
//
// Seuls les accès que la synchronisation a elle-même accordés sont retirés
// (suivis dans config/settings.driveAccessGrants, par identifiant de
// permission Drive) — jamais un partage ajouté manuellement pour une autre
// raison, comme le compte propriétaire de l'arborescence.
import '../models/drive_access_folder.dart';
import '../models/member.dart';
import 'drive_service.dart';
import 'firestore_repository.dart';

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
  const DriveAccessSyncResult({
    required this.granted,
    required this.revoked,
    required this.failed,
    required this.driftCorrected,
  });

  bool get isEmpty =>
      granted.isEmpty &&
      revoked.isEmpty &&
      failed.isEmpty &&
      driftCorrected.isEmpty;
}

/// Accès réels d'un dossier, lus en direct sur Drive (pas depuis le suivi
/// Firestore) — pour la section « Accès existants » de l'écran.
class FolderAccessSummary {
  final String folderName;
  final List<({String email, String role})> entries;
  const FolderAccessSummary({required this.folderName, required this.entries});
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

    for (final folder in folders) {
      final current = Map<String, String>.from(grants[folder.folderId] ?? {});

      // Dérive : une permission notée dans Firestore n'existe peut-être
      // plus réellement sur Drive (retirée à la main, appel précédent en
      // échec silencieux). Vérifiée AVANT de décider quoi ajouter/retirer,
      // pour ne jamais se fier à un état périmé.
      for (final email in current.keys.toList()) {
        final permissionId = current[email]!;
        bool exists;
        try {
          exists = await _drive.permissionExists(
            folderId: folder.folderId,
            permissionId: permissionId,
          );
        } catch (e) {
          failed.add('$email — ${folder.name} (vérification) : $e');
          continue;
        }
        if (!exists) {
          current.remove(email);
          driftCorrected.add('$email — ${folder.name}');
        }
      }

      final shouldHave = <String>{
        for (final m in members)
          if (m.email.trim().isNotEmpty &&
              driveRolesFor(m).any(folder.roles.contains))
            m.email.trim().toLowerCase(),
      };

      // Retraits : accordé par une précédente synchronisation, mais le
      // titulaire n'a plus une fonction couverte par ce dossier.
      for (final email in current.keys.toList()) {
        if (shouldHave.contains(email)) continue;
        final permissionId = current[email]!;
        try {
          await _drive.revokeFolderAccess(
            folderId: folder.folderId,
            permissionId: permissionId,
          );
          current.remove(email);
          revoked.add('$email — ${folder.name}');
        } catch (e) {
          failed.add('$email — ${folder.name} (retrait) : $e');
        }
      }

      // Ajouts : fonction couverte par ce dossier, pas encore d'accès.
      for (final email in shouldHave) {
        if (current.containsKey(email)) continue;
        try {
          final permissionId = await _drive.grantFolderAccess(
            folderId: folder.folderId,
            email: email,
          );
          current[email] = permissionId;
          granted.add('$email — ${folder.name}');
        } catch (e) {
          failed.add('$email — ${folder.name} (ajout) : $e');
        }
      }

      grants[folder.folderId] = current;
    }

    await _repo.setDriveAccessGrants(grants);
    return DriveAccessSyncResult(
      granted: granted,
      revoked: revoked,
      failed: failed,
      driftCorrected: driftCorrected,
    );
  }

  /// Photo des accès réels, dossier par dossier, lue en direct sur Drive —
  /// révèle aussi un partage ajouté à la main en dehors de cette
  /// synchronisation, ce que le suivi Firestore ne montrerait jamais.
  Future<List<FolderAccessSummary>> currentAccess() async {
    final folders = await _repo.getDriveAccessFolders();
    final summaries = <FolderAccessSummary>[];
    for (final folder in folders) {
      final entries = await _drive.listFolderAccess(folderId: folder.folderId);
      summaries.add(
        FolderAccessSummary(folderName: folder.name, entries: entries),
      );
    }
    return summaries;
  }
}
