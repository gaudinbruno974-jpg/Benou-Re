// Action du bouton « Synchroniser les membres » (écran Membres, IAH-MES
// uniquement) : IAH-MES réunit les membres des 4 loges bleues ayant un
// degré (Hauts Grades) strictement supérieur à 3 — chacun devient un
// Membre IAH-MES (fonction vide, loge d'origine en Loge mère), sauf ceux
// déjà présents (comparaison par nom), même principe que la synchro
// équivalente MAA-Kherou (grande_loge_hg_maakherou_member_sync_actions.dart).
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../models/member.dart';
import '../services/grande_loge_directory_sync.dart'
    show kBlueLodgeDisplayName, kBlueLodgeObedience, kBlueLodgeOrient;
import '../services/hg_body_service.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';

String _foldName(String first, String last) => foldLabel('$first $last');

Future<void> runIahMesMemberSync(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Lecture des 4 loges bleues en cours...')),
  );
  final List<List<Member>> blueMembers;
  try {
    blueMembers = await Future.wait([
      for (final target in kLodgeReaderTargets)
        LodgeReaderService.instance.membersOf(target),
    ]);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture des loges) : $e')),
    );
    return;
  }

  final List<Member> existing;
  try {
    existing = await HgBodyService.instance.membersOnce(kIahMes);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture IAH-MES) : $e')),
    );
    return;
  }

  final toCreate = <Member>[];
  for (var i = 0; i < kLodgeReaderTargets.length; i++) {
    final target = kLodgeReaderTargets[i];
    for (final m in blueMembers[i]) {
      if (kHiddenTechnicalRoles.contains(m.role)) continue;
      if ((int.tryParse(m.hautsGradesDegree) ?? 0) <= 3) continue;
      final key = _foldName(m.firstName, m.lastName);
      final already =
          existing.firstWhereOrNull(
            (e) => _foldName(e.firstName, e.lastName) == key,
          ) ??
          toCreate.firstWhereOrNull(
            (e) => _foldName(e.firstName, e.lastName) == key,
          );
      if (already != null) continue;
      toCreate.add(
        Member(
          id: '',
          civilite: m.civilite,
          firstName: m.firstName,
          lastName: m.lastName,
          grade: m.grade,
          email: m.email,
          phone: m.phone,
          hautsGradesDegree: m.hautsGradesDegree,
          motherLodge: kBlueLodgeDisplayName[target.key] ?? target.label,
          obedience: kBlueLodgeObedience,
          orient: kBlueLodgeOrient,
        ),
      );
    }
  }

  messenger.hideCurrentSnackBar();
  if (toCreate.isEmpty) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Rien à faire : tous les membres au-delà du 3e degré sont déjà '
          'membres IAH-MES.',
        ),
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
        'Confirmer la synchronisation ?',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Text(
          '${toCreate.length} membre(s) seront ajoutés à IAH-MES (degré '
          '> 3 dans les 4 loges bleues, absents pour l\'instant), fonction '
          'vide à compléter ensuite à la main.',
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
  if (confirmed != true || !context.mounted) return;

  messenger.showSnackBar(
    SnackBar(
      content: Text('Synchronisation 0/${toCreate.length}...'),
      duration: const Duration(minutes: 5),
    ),
  );
  var done = 0;
  try {
    for (final m in toCreate) {
      await HgBodyService.instance.saveMember(kIahMes, m);
      done++;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Synchronisation $done/${toCreate.length}...'),
          duration: const Duration(minutes: 5),
        ),
      );
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Synchronisation terminée : $done membre(s) ajouté(s).'),
        backgroundColor: BrColors.teal,
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Erreur pendant la synchronisation (après $done/${toCreate.length}) : $e',
        ),
      ),
    );
  }
}
