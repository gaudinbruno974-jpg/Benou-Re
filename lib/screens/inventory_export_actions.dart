// Export du classeur Matériel (et de son modèle vide) en téléchargement
// local — même principe que directory_export_actions.dart pour les
// répertoires Membres/Visiteurs/Dignitaires.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/inventory_xlsx_service.dart';
import '../state/app_state.dart';
import 'directory_export_actions.dart' show saveFileLocally;

/// Exporte l'inventaire du matériel, téléchargé localement.
Future<void> exportInventory(BuildContext context) async {
  final state = context.read<AppState>();
  final bytes = buildInventoryWorkbook(state.inventoryItems);
  final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
  final loge = LodgeConfig.current.name.replaceAll(' ', '_');
  final fileName = 'Inventaire_Materiel_${loge}_du_$date.xlsx';
  await saveFileLocally(context, fileName, bytes);
}

/// Télécharge un classeur modèle (en-têtes seuls, sans donnée).
Future<void> exportInventoryTemplate(BuildContext context) async {
  final bytes = buildInventoryTemplate();
  final fileName = 'Modele_Import_Materiel_'
      '${LodgeConfig.current.name.replaceAll(' ', '_')}.xlsx';
  await saveFileLocally(context, fileName, bytes);
}
