// Export du classeur Membres/Visiteurs/Dignitaires (et de son modèle vide)
// d'un corps de Hauts Grades — même principe que directory_export_actions.dart
// (loges bleues), adapté : pas de LodgeConfig, archivage Drive générique
// (archiveGenericDocument) plutôt que le dossier dédié des loges bleues.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hg_body.dart';
import '../services/directory_xlsx_service.dart';
import '../services/drive_service.dart';
import '../services/hg_body_service.dart';
import '../services/hg_drive_folders.dart';
import 'directory_export_actions.dart' show saveFileLocally;

/// Exporte les trois répertoires (Membres, Visiteurs, Dignitaires) d'un
/// corps de Hauts Grades en un classeur unique, téléchargé localement puis
/// archivé sur Drive (best-effort).
Future<void> exportHgDirectories(BuildContext context, HgBody body) async {
  final members = await HgBodyService.instance.membersOnce(body);
  final visitors = await HgBodyService.instance.visitorsStream(body).first;
  final dignitaries = await HgBodyService.instance
      .dignitariesStream(body)
      .first;
  final bytes = buildDirectoryWorkbook(
    members: members,
    visitors: visitors,
    dignitaries: dignitaries,
  );
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final fileName = 'Repertoires_${body.label.replaceAll(' ', '_')}_$date.xlsx';
  if (!context.mounted) return;
  await saveFileLocally(context, fileName, bytes);

  final driveDate = DateFormat('dd MM yy').format(DateTime.now());
  try {
    await DriveService.instance.archiveGenericDocument(
      folderPath: hgRepertoiresDrivePath(body),
      fileName: 'Repertoires ${body.label} $driveDate.xlsx',
      bytes: Uint8List.fromList(bytes),
      contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  } catch (_) {
    // Best-effort : l'export local a déjà réussi.
  }
}

/// Télécharge un classeur modèle (en-têtes seuls, sans donnée), pour servir
/// de base à l'import d'un autre corps.
Future<void> exportHgDirectoryTemplate(
  BuildContext context,
  HgBody body,
) async {
  final bytes = buildDirectoryTemplate();
  final fileName =
      'Modele_Import_Repertoires_${body.label.replaceAll(' ', '_')}.xlsx';
  await saveFileLocally(context, fileName, bytes);
}
