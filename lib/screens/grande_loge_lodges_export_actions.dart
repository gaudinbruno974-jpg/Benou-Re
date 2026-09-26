// Export Excel groupé des répertoires (Membres, Visiteurs, Dignitaires) des 4
// loges bleues, depuis la Grande Loge — lecture croisée
// (LodgeReaderService), un seul classeur à trois onglets avec une colonne
// « Loge bleue » (voir buildMultiLodgeDirectoryWorkbook). Téléchargement
// local uniquement, pas d'archivage Drive : le fichier contient des données
// personnelles de tous les membres.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/directory_xlsx_service.dart';
import '../services/lodge_reader_service.dart';
import 'directory_export_actions.dart' show saveFileLocally;

Future<LodgeDirectory> _readLodge(LodgeReaderTarget target) async {
  final reader = LodgeReaderService.instance;
  // Les trois lectures démarrent ensemble, puis on attend chacune.
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

Future<void> exportAllLodgesDirectories(BuildContext context) async {
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
      SnackBar(content: Text('Export impossible (lecture des loges) : $e')),
    );
    return;
  }
  final bytes = buildMultiLodgeDirectoryWorkbook(lodges);
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  messenger.hideCurrentSnackBar();
  if (!context.mounted) return;
  await saveFileLocally(context, 'Membres_4_Loges_$date.xlsx', bytes);
}
