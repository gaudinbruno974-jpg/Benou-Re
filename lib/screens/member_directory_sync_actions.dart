// Action du bouton « Synchroniser les membres » (écran Accès Drive, Bénou Ré,
// visible uniquement par le compte de l'utilisateur) : calcule le plan à
// partir des Répertoires de Membres des 4 loges (voir
// grande_loge_directory_sync.dart:computeMemberSyncPlan), l'affiche pour
// confirmation avant toute écriture, puis l'applique et montre un rapport.
import 'package:flutter/material.dart';

import '../services/directory_xlsx_service.dart' show LodgeDirectory;
import '../services/grande_loge_directory_sync.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';

Future<LodgeDirectory> _readLodge(LodgeReaderTarget target) async {
  final reader = LodgeReaderService.instance;
  final members = reader.membersOf(target);
  final visitors = reader.visitorsOf(target);
  final dignitaries = reader.dignitariesOf(target);
  return LodgeDirectory(
    lodgeName: target.label,
    members: await members,
    visitors: await visitors,
    dignitaries: await dignitaries,
  );
}

/// Résultat affiché après écriture — voir [DriveAccessSyncScreen] pour le
/// même principe de rapport sur la synchro des accès Drive.
class MemberSyncReport {
  final int creationsCount;
  final int fixesCount;
  final List<String> manualReview;
  const MemberSyncReport({
    required this.creationsCount,
    required this.fixesCount,
    required this.manualReview,
  });
}

Future<MemberSyncReport?> runMemberSync(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Lecture des 4 loges en cours...')),
  );
  final List<LodgeDirectory> lodges;
  try {
    lodges = await Future.wait([
      for (final target in kLodgeReaderTargets) _readLodge(target),
    ]);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture des loges) : $e')),
    );
    return null;
  }
  messenger.hideCurrentSnackBar();

  final plan = computeMemberSyncPlan(kLodgeReaderTargets, lodges);
  if (plan.totalChanges == 0 && plan.manualReview.isEmpty) {
    if (!context.mounted) return null;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Rien à faire : les membres des 4 loges sont déjà partagés.',
        ),
        backgroundColor: BrColors.teal,
      ),
    );
    return const MemberSyncReport(
      creationsCount: 0,
      fixesCount: 0,
      manualReview: [],
    );
  }

  if (!context.mounted) return null;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BrColors.surface,
      title: const Text(
        'Confirmer la synchronisation ?',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Text(
          '${plan.creationsCount} fiche(s) seront ajoutées (chaque membre '
          'devient Visiteur chez les 3 autres loges, le V∴M∴ devient '
          'Dignitaire), ${plan.fixes.length} fiche(s) auront leur téléphone '
          'ou nom corrigé.'
          '${plan.manualReview.isEmpty ? '' : '\n\n${plan.manualReview.length} cas nécessitent une correction manuelle (détail dans le rapport).'}',
          style: const TextStyle(color: BrColors.muted),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Synchroniser'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return null;
  }

  var done = 0;
  final total = plan.totalChanges;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Synchronisation 0/$total...'),
      duration: const Duration(minutes: 5),
    ),
  );
  try {
    await applyMemberSyncPlan(
      plan,
      onProgress: (d, t) {
        done = d;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Synchronisation $d/$t...'),
            duration: const Duration(minutes: 5),
          ),
        );
      },
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Synchronisation terminée : $done fiche(s) modifiée(s) ou ajoutée(s).',
        ),
        backgroundColor: BrColors.teal,
      ),
    );
    return MemberSyncReport(
      creationsCount: plan.creationsCount,
      fixesCount: plan.fixes.length,
      manualReview: plan.manualReview,
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Erreur pendant la synchronisation (après $done/$total) : $e',
        ),
      ),
    );
    return null;
  }
}
