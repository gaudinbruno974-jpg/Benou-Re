// Export du classeur Membres/Visiteurs/Dignitaires (et de son modèle vide)
// vers le dossier Drive de sauvegarde de la Loge — partagé par les trois
// écrans de répertoire (Membres, Visiteurs, Dignitaires), qui produisent
// tous le même classeur complet quel que soit celui d'où on clique.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/directory_xlsx_service.dart';
import '../services/drive_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

Future<void> _upload(
  BuildContext context,
  String fileName,
  List<int> bytes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final folderId = LodgeConfig.current.backupFolderId.trim();
  if (folderId.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Aucun dossier de sauvegarde Drive n'est configuré pour cette Loge.",
        ),
      ),
    );
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text('Envoi de « $fileName »…')));
  try {
    await DriveService.instance.uploadFileToFolder(
      folderId,
      fileName,
      Uint8List.fromList(bytes),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('« $fileName » déposé sur le Drive.'),
        backgroundColor: BrColors.teal,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Erreur d\'envoi : $e')));
  }
}

/// Exporte les trois répertoires (Membres, Visiteurs, Dignitaires) en un
/// classeur unique, déposé sur le Drive de la Loge.
Future<void> exportDirectoriesToDrive(BuildContext context) async {
  final state = context.read<AppState>();
  final bytes = buildDirectoryWorkbook(
    members: state.members,
    visitors: state.visitors,
    dignitaries: state.dignitaries,
  );
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final fileName =
      'Repertoires_${LodgeConfig.current.name.replaceAll(' ', '_')}_$date.xlsx';
  await _upload(context, fileName, bytes);
}

/// Dépose un classeur modèle (en-têtes seuls, sans donnée) sur le Drive de
/// la Loge, pour servir de base à l'import d'une autre Loge.
Future<void> exportDirectoryTemplateToDrive(BuildContext context) async {
  final bytes = buildDirectoryTemplate();
  await _upload(context, 'Modele_Import_Repertoires.xlsx', bytes);
}
