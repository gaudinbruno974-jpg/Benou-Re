// Action du bouton « Synchroniser les membres » (écran Membres, MAA-Kherou
// uniquement) : MAA-Kherou réunit les Maîtres des 4 loges bleues — chacun
// devient un Membre MAA-Kherou (grade Maître, fonction vide, loge d'origine
// en Loge mère), sauf ceux déjà présents (comparaison par nom), même
// principe de plan + confirmation + rapport que grande_loge_directory_sync.dart.
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import '../services/grande_loge_directory_sync.dart'
    show kBlueLodgeDisplayName, kBlueLodgeObedience, kBlueLodgeOrient;
import '../services/hg_body_service.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';

String _foldName(String first, String last) => foldLabel('$first $last');

Future<void> runMaaKherouMemberSync(BuildContext context) async {
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
    existing = await HgBodyService.instance.membersOnce(kMaaKherou);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture MAA-Kherou) : $e')),
    );
    return;
  }

  final toCreate = <Member>[];
  for (var i = 0; i < kLodgeReaderTargets.length; i++) {
    final target = kLodgeReaderTargets[i];
    for (final m in blueMembers[i]) {
      if (kHiddenTechnicalRoles.contains(m.role)) continue;
      if (m.grade != kMaitre) continue;
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
          grade: kMaitre,
          email: m.email,
          phone: m.phone,
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
          'Rien à faire : tous les Maîtres des 4 loges sont déjà membres.',
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
          '${toCreate.length} membre(s) seront ajoutés à MAA-Kherou '
          '(Maîtres des 4 loges bleues absents pour l\'instant), fonction '
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
      await HgBodyService.instance.saveMember(kMaaKherou, m);
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

/// Dignitaires MAA-Kherou : TOUS les dignitaires déjà connus des 4 loges
/// bleues (honneurs extérieurs à la GLDB), sans filtre de grade — sauf ceux
/// dont le titre est Vénérable Maître, qui vont dans les Visiteurs de
/// MAA-Kherou plutôt que dans ses Dignitaires (demande explicite de
/// l'utilisateur : un titre de loge bleue, pas un honneur MAA-Kherou).
Future<void> runMaaKherouDignitarySync(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Lecture des 4 loges bleues en cours...')),
  );
  final List<List<Dignitary>> blueDignitaries;
  try {
    blueDignitaries = await Future.wait([
      for (final target in kLodgeReaderTargets)
        LodgeReaderService.instance.dignitariesOf(target),
    ]);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture des loges) : $e')),
    );
    return;
  }

  final List<Dignitary> existingDignitaries;
  final List<Visitor> existingVisitors;
  final List<Member> existingMembers;
  try {
    existingDignitaries = await HgBodyService.instance
        .dignitariesStream(kMaaKherou)
        .first;
    existingVisitors = await HgBodyService.instance
        .visitorsStream(kMaaKherou)
        .first;
    existingMembers = await HgBodyService.instance.membersOnce(kMaaKherou);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture MAA-Kherou) : $e')),
    );
    return;
  }

  final seen = <String>{
    for (final d in existingDignitaries) _foldName(d.firstName, d.lastName),
    for (final v in existingVisitors) _foldName(v.firstName, v.lastName),
    for (final m in existingMembers) _foldName(m.firstName, m.lastName),
  };
  final dignitariesToCreate = <Dignitary>[];
  final visitorsToCreate = <Visitor>[];
  for (final lodgeDignitaries in blueDignitaries) {
    for (final d in lodgeDignitaries) {
      final key = _foldName(d.firstName, d.lastName);
      if (seen.contains(key)) continue;
      seen.add(key);
      if (foldLabel(d.title).contains('venerable maitre')) {
        visitorsToCreate.add(
          Visitor(
            id: '',
            civilite: d.civilite,
            firstName: d.firstName,
            lastName: d.lastName,
            grade: d.grade,
            function: d.title,
            lodge: d.lodge,
            orient: d.orient,
            obedience: d.obedience,
            email: d.email,
            phone: d.phone,
          ),
        );
      } else {
        dignitariesToCreate.add(
          Dignitary(
            id: '',
            civilite: d.civilite,
            firstName: d.firstName,
            lastName: d.lastName,
            title: d.title,
            lodge: d.lodge,
            orient: d.orient,
            obedience: d.obedience,
            email: d.email,
            phone: d.phone,
            preferredContact: d.preferredContact,
            protocolRank: d.protocolRank,
          ),
        );
      }
    }
  }
  final total = dignitariesToCreate.length + visitorsToCreate.length;

  messenger.hideCurrentSnackBar();
  if (total == 0) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Rien à faire : les dignitaires sont déjà à jour.'),
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
          '${dignitariesToCreate.length} dignitaire(s) et '
          '${visitorsToCreate.length} visiteur(s) (Vénérables Maîtres des '
          'loges bleues, déjà connus comme dignitaires quelque part) seront '
          'ajoutés à MAA-Kherou.',
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
      content: Text('Synchronisation 0/$total...'),
      duration: const Duration(minutes: 5),
    ),
  );
  var done = 0;
  try {
    for (final d in dignitariesToCreate) {
      await HgBodyService.instance.saveDignitary(kMaaKherou, d);
      done++;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Synchronisation $done/$total...'),
          duration: const Duration(minutes: 5),
        ),
      );
    }
    for (final v in visitorsToCreate) {
      await HgBodyService.instance.saveVisitor(kMaaKherou, v);
      done++;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Synchronisation $done/$total...'),
          duration: const Duration(minutes: 5),
        ),
      );
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Synchronisation terminée : $done fiche(s) ajoutée(s).'),
        backgroundColor: BrColors.teal,
      ),
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
  }
}

/// Visiteurs MAA-Kherou : les visiteurs des 4 loges bleues qui sont au
/// grade Maître ET dont la loge n'est pas une des 4 loges bleues de la
/// GLDB (sinon ils sont déjà Membres via [runMaaKherouMemberSync]) —
/// demande explicite de l'utilisateur.
Future<void> runMaaKherouVisitorSync(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Lecture des 4 loges bleues en cours...')),
  );
  final List<List<Visitor>> blueVisitors;
  try {
    blueVisitors = await Future.wait([
      for (final target in kLodgeReaderTargets)
        LodgeReaderService.instance.visitorsOf(target),
    ]);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture des loges) : $e')),
    );
    return;
  }

  final List<Visitor> existingVisitors;
  final List<Member> existingMembers;
  try {
    existingVisitors = await HgBodyService.instance
        .visitorsStream(kMaaKherou)
        .first;
    existingMembers = await HgBodyService.instance.membersOnce(kMaaKherou);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Synchro impossible (lecture MAA-Kherou) : $e')),
    );
    return;
  }

  final gldbLodgeNames = kBlueLodgeDisplayName.values.toSet();
  final seen = <String>{
    for (final v in existingVisitors) _foldName(v.firstName, v.lastName),
    for (final m in existingMembers) _foldName(m.firstName, m.lastName),
  };
  final toCreate = <Visitor>[];
  for (final lodgeVisitors in blueVisitors) {
    for (final v in lodgeVisitors) {
      if (v.grade != kMaitre) continue;
      if (gldbLodgeNames.contains(v.lodge.trim())) continue;
      final key = _foldName(v.firstName, v.lastName);
      if (seen.contains(key)) continue;
      seen.add(key);
      toCreate.add(
        Visitor(
          id: '',
          civilite: v.civilite,
          firstName: v.firstName,
          lastName: v.lastName,
          grade: v.grade,
          function: v.function,
          lodge: v.lodge,
          orient: v.orient,
          obedience: v.obedience,
          email: v.email,
          phone: v.phone,
        ),
      );
    }
  }

  messenger.hideCurrentSnackBar();
  if (toCreate.isEmpty) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Rien à faire : les visiteurs sont déjà à jour.'),
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
          '${toCreate.length} visiteur(s) Maître(s) hors GLDB seront '
          'ajoutés à MAA-Kherou.',
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
    for (final v in toCreate) {
      await HgBodyService.instance.saveVisitor(kMaaKherou, v);
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
        content: Text(
          'Synchronisation terminée : $done visiteur(s) ajouté(s).',
        ),
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
