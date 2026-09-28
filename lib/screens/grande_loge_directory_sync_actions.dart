// Action du bouton « MAJ des Membres » (écran Loges Bleues, Grande Loge) :
// calcule le plan de synchronisation (voir grande_loge_directory_sync.dart),
// l'affiche pour confirmation avant toute écriture, puis l'applique. Jamais
// de création/suppression de Membres, jamais d'écriture silencieuse.
import 'package:flutter/material.dart';

import '../services/directory_xlsx_service.dart';
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

Future<void> runDirectorySync(BuildContext context) async {
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
      SnackBar(content: Text('MAJ impossible (lecture des loges) : $e')),
    );
    return;
  }
  messenger.hideCurrentSnackBar();

  final plan = computeDirectorySyncPlan(kLodgeReaderTargets, lodges);
  if (plan.totalChanges == 0) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Rien à mettre à jour, les 4 loges sont déjà à jour.'),
        backgroundColor: BrColors.teal,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: BrColors.surface,
      title: const Text(
        'Confirmer la mise à jour ?',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Text(
          '${plan.creationsCount} fiche(s) manquante(s) seront ajoutées '
          '(Visiteurs/Dignitaires), ${plan.fixes.length} fiche(s) auront '
          'leur téléphone ou nom corrigé (Membres/Visiteurs/Dignitaires), '
          'dans les 4 loges. Aucun membre n\'est créé, modifié dans un autre '
          'champ, ni supprimé.',
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
          child: const Text('Mettre à jour'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  var done = 0;
  final total = plan.totalChanges;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Mise à jour 0/$total...'),
      duration: const Duration(minutes: 5),
    ),
  );
  try {
    await applyDirectorySyncPlan(
      plan,
      onProgress: (d, t) {
        done = d;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Mise à jour $d/$t...'),
            duration: const Duration(minutes: 5),
          ),
        );
      },
    );
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Mise à jour terminée : $done fiche(s) modifiée(s) ou ajoutée(s).',
        ),
        backgroundColor: BrColors.teal,
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Erreur pendant la mise à jour (après $done/$total) : $e',
        ),
      ),
    );
  }
}
