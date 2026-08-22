// Import du Matériel depuis un classeur .xlsx : sélection du fichier ->
// aperçu des lignes détectées (avec choix ligne par ligne pour chaque
// doublon) -> confirmation récapitulative -> écriture réelle. Même déroulé
// que directory_import_screen.dart (Membres/Visiteurs/Dignitaires) — voir
// inventory_xlsx_service.dart pour la détection de doublon et la résolution
// de chaque ligne.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/directory_xlsx_service.dart' show ImportAction;
import '../services/inventory_xlsx_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'inventory_export_actions.dart';

enum _Step { intro, loading, preview, writing, done, error }

class InventoryImportScreen extends StatefulWidget {
  const InventoryImportScreen({super.key});

  @override
  State<InventoryImportScreen> createState() => _InventoryImportScreenState();
}

class _InventoryImportScreenState extends State<InventoryImportScreen> {
  _Step _step = _Step.intro;
  String? _errorMessage;
  List<InventoryImportRow> _rows = const [];
  String _fileName = '';
  int _createdCount = 0;
  int _updatedCount = 0;

  Future<void> _pickFile() async {
    setState(() => _step = _Step.loading);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) {
        setState(() => _step = _Step.intro);
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Impossible de lire le contenu du fichier.';
          _step = _Step.error;
        });
        return;
      }
      final state = context.read<AppState>();
      final rows = parseInventorySheet(bytes, state.inventoryItems);
      setState(() {
        _fileName = file.name;
        _rows = rows;
        _step = _Step.preview;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fichier illisible ou format inattendu : $e';
        _step = _Step.error;
      });
    }
  }

  Future<void> _confirmAndWrite() async {
    final toWrite = _rows.where((r) => r.action != ImportAction.skip).toList();
    final creations = toWrite.where((r) => r.action == ImportAction.create).length;
    final updates = toWrite.where((r) => r.action == ImportAction.update).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          "Confirmer l'import ?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$creations article(s) seront créés et $updates article(s) '
          "existants seront mis à jour dans l'inventaire. Cette action "
          'écrit directement dans la base de la Loge.',
          style: const TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _step = _Step.writing);
    final state = context.read<AppState>();
    var created = 0;
    var updated = 0;
    var seq = 0;
    String newId() =>
        'inv_${DateTime.now().millisecondsSinceEpoch}_${seq++}';

    for (final row in toWrite) {
      final item = row.resolve(newId);
      if (item == null) continue;
      if (row.action == ImportAction.create) {
        await state.addInventoryItem(item);
        created++;
      } else {
        await state.updateInventoryItem(item);
        updated++;
      }
    }

    if (!mounted) return;
    setState(() {
      _createdCount = created;
      _updatedCount = updated;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer — Matériel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_step) {
          _Step.intro => _buildIntro(),
          _Step.loading => const Center(
            child: CircularProgressIndicator(color: BrColors.gold),
          ),
          _Step.preview => _buildPreview(),
          _Step.writing => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: BrColors.gold),
                SizedBox(height: 16),
                Text('Écriture en cours…', style: TextStyle(color: BrColors.muted)),
              ],
            ),
          ),
          _Step.done => _buildDone(),
          _Step.error => _buildError(),
        },
      ),
    );
  }

  Widget _buildIntro() {
    return ListView(
      children: [
        const Text(
          'Sélectionnez un classeur .xlsx contenant une feuille '
          '« Matériel » — même format que celui produit par « Exporter ». '
          "Rien n'est écrit tant que vous n'avez pas validé un écran de "
          'confirmation.',
          style: TextStyle(color: BrColors.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Choisir un fichier .xlsx'),
          onPressed: _pickFile,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.description_outlined),
          label: const Text('Télécharger un modèle vide'),
          onPressed: () => exportInventoryTemplate(context),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: BrColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'Erreur inconnue.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrColors.muted),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => setState(() => _step = _Step.intro),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: BrColors.menuVisiteurs, size: 40),
          const SizedBox(height: 12),
          Text(
            '$_createdCount article(s) créé(s), $_updatedCount mis à jour.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrColors.text),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final creations = _rows.where((r) => r.action == ImportAction.create).length;
    final updates = _rows.where((r) => r.action == ImportAction.update).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_fileName, style: const TextStyle(color: BrColors.gold, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BrBadge(label: '$creations création(s)', color: BrColors.menuVisiteurs),
            BrBadge(label: '$updates mise(s) à jour', color: BrColors.gold),
          ],
        ),
        const SizedBox(height: 14),
        if (_rows.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Aucune ligne détectée dans cette feuille.',
                style: TextStyle(color: BrColors.muted),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                for (final row in _rows)
                  _ImportRowCard(row: row, onChanged: () => setState(() {})),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text("Valider l'import"),
            onPressed: (creations + updates) == 0 ? null : _confirmAndWrite,
          ),
        ),
      ],
    );
  }
}

class _ImportRowCard extends StatelessWidget {
  final InventoryImportRow row;
  final VoidCallback onChanged;
  const _ImportRowCard({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasExisting = row.existing != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrCard(
        accent: hasExisting ? BrColors.gold : BrColors.menuVisiteurs,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    style: const TextStyle(color: BrColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (row.category.isNotEmpty)
                    Text(
                      row.category,
                      style: const TextStyle(color: BrColors.muted, fontSize: 11),
                    ),
                  Text(
                    hasExisting ? 'Doublon détecté' : 'Nouvel article',
                    style: TextStyle(
                      color: hasExisting ? BrColors.gold : BrColors.menuVisiteurs,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<ImportAction>(
              value: row.action,
              dropdownColor: BrColors.surface,
              style: const TextStyle(color: BrColors.text, fontSize: 12),
              items: [
                if (hasExisting)
                  const DropdownMenuItem(value: ImportAction.update, child: Text('Mettre à jour')),
                DropdownMenuItem(
                  value: ImportAction.create,
                  child: Text(hasExisting ? 'Créer quand même' : 'Créer'),
                ),
                const DropdownMenuItem(value: ImportAction.skip, child: Text('Ignorer')),
              ],
              onChanged: (v) {
                row.action = v ?? (hasExisting ? ImportAction.update : ImportAction.create);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
