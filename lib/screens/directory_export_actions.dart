// Export du classeur Membres/Visiteurs/Dignitaires (et de son modèle vide)
// en téléchargement local — partagé par les trois écrans de répertoire
// (Membres, Visiteurs, Dignitaires), qui produisent tous le même classeur
// complet à trois feuilles, quel que soit celui d'où on clique.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/directory_xlsx_service.dart';
import '../services/drive_service.dart';
import '../services/local_file_saver.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Enregistre [bytes] localement sous [fileName], avec la confirmation ou le
/// message d'erreur adapté — partagé par tous les exports de classeur .xlsx
/// de l'app (répertoires, matériel).
Future<void> saveFileLocally(
  BuildContext context,
  String fileName,
  List<int> bytes,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // Web : `FilePicker.platform.saveFile` n'y est pas implémenté (voir
    // local_file_saver_web.dart) — on passe par la boîte de dialogue
    // « Enregistrer sous » native du navigateur à la place. Sur les autres
    // plateformes (Android), trySaveFileNatively renvoie toujours `false` et
    // on garde FilePicker, qui y fonctionne déjà.
    if (await trySaveFileNatively(fileName, bytes)) return;
    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (path == null) return; // annulé par l'utilisateur
    messenger.showSnackBar(
      SnackBar(
        content: Text('« $fileName » enregistré.'),
        backgroundColor: BrColors.teal,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Erreur d\'export : $e')));
  }
}

/// Exporte les trois répertoires (Membres, Visiteurs, Dignitaires) en un
/// classeur unique, téléchargé localement.
Future<void> exportDirectories(BuildContext context) async {
  final state = context.read<AppState>();
  final bytes = buildDirectoryWorkbook(
    members: state.members,
    visitors: state.visitors,
    dignitaries: state.dignitaries,
  );
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final fileName =
      'Repertoires_${LodgeConfig.current.name.replaceAll(' ', '_')}_$date.xlsx';
  await saveFileLocally(context, fileName, bytes);

  final loge = LodgeConfig.current.name;
  final driveDate = DateFormat('dd MM yy').format(DateTime.now());
  try {
    await DriveService.instance.archiveDirectoryDocument(
      namePrefix: 'Repertoires $loge',
      fileName: 'Repertoires $loge $driveDate.xlsx',
      bytes: Uint8List.fromList(bytes),
    );
  } catch (_) {
    // Best-effort : l'export local a déjà réussi, on n'interrompt pas
    // l'utilisateur pour un archivage Drive en échec.
  }
}

/// Télécharge un classeur modèle (en-têtes seuls, sans donnée), pour servir
/// de base à l'import d'une autre Loge.
Future<void> exportDirectoryTemplate(BuildContext context) async {
  final bytes = buildDirectoryTemplate();
  final fileName = 'Modele_Import_Repertoires_'
      '${LodgeConfig.current.name.replaceAll(' ', '_')}.xlsx';
  await saveFileLocally(context, fileName, bytes);
}
