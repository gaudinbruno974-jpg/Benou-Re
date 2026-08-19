// Import groupé des répertoires Membres/Visiteurs/Dignitaires depuis un
// classeur .xlsx à trois onglets : sélection du fichier → aperçu des lignes
// détectées (avec choix ligne par ligne pour chaque doublon) → confirmation
// récapitulative → écriture réelle. Voir directory_xlsx_service.dart pour
// la détection de doublon et la résolution de chaque ligne.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/directory_xlsx_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'directory_export_actions.dart';

enum _Step { intro, loading, preview, writing, done, error }

/// Action retenue pour une ligne, quel que soit son type — les trois classes
/// de ligne d'import n'ont pas d'interface commune (voir
/// directory_xlsx_service.dart), d'où ce petit aiguillage partagé.
ImportAction _rowAction(Object row) => switch (row) {
  MemberImportRow r => r.action,
  VisitorImportRow r => r.action,
  DignitaryImportRow r => r.action,
  _ => ImportAction.skip,
};

class DirectoryImportScreen extends StatefulWidget {
  const DirectoryImportScreen({super.key});

  @override
  State<DirectoryImportScreen> createState() => _DirectoryImportScreenState();
}

class _DirectoryImportScreenState extends State<DirectoryImportScreen> {
  _Step _step = _Step.intro;
  String? _errorMessage;
  DirectoryImportPreview? _preview;
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
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: state.members,
        existingVisitors: state.visitors,
        existingDignitaries: state.dignitaries,
      );
      setState(() {
        _fileName = file.name;
        _preview = preview;
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
    final preview = _preview;
    if (preview == null) return;
    final toWrite = <Object>[
      ...preview.members.where((r) => r.action != ImportAction.skip),
      ...preview.visitors.where((r) => r.action != ImportAction.skip),
      ...preview.dignitaries.where((r) => r.action != ImportAction.skip),
    ];
    final creations =
        toWrite.where((r) => _rowAction(r) == ImportAction.create).length;
    final updates =
        toWrite.where((r) => _rowAction(r) == ImportAction.update).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          "Confirmer l'import ?",
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '$creations fiche(s) seront créées et $updates fiche(s) existantes '
          'seront mises à jour. Cette action écrit directement dans la base '
          'de la Loge.',
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
    String newId(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${seq++}';

    for (final row in preview.members) {
      if (row.action == ImportAction.skip) continue;
      final member = row.resolve(() => newId('m'));
      if (member == null) continue;
      if (row.action == ImportAction.create) {
        await state.addMember(member);
        created++;
      } else {
        await state.updateMember(member);
        updated++;
      }
    }
    for (final row in preview.visitors) {
      if (row.action == ImportAction.skip) continue;
      final visitor = row.resolve(() => newId('v'));
      if (visitor == null) continue;
      if (row.action == ImportAction.create) {
        await state.addVisitor(visitor);
        created++;
      } else {
        await state.updateVisitor(visitor);
        updated++;
      }
    }
    for (final row in preview.dignitaries) {
      if (row.action == ImportAction.skip) continue;
      final dignitary = row.resolve(() => newId('d'));
      if (dignitary == null) continue;
      if (row.action == ImportAction.create) {
        await state.addDignitary(dignitary);
        created++;
      } else {
        await state.updateDignitary(dignitary);
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
      appBar: AppBar(title: const Text('Importer les répertoires')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (_step) {
          _Step.intro => _buildIntro(),
          _Step.loading => const Center(
            child: CircularProgressIndicator(color: BrColors.gold),
          ),
          _Step.preview => _buildPreview(_preview!),
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
          'Sélectionnez un classeur .xlsx à trois onglets (Membres, '
          'Visiteurs, Dignitaires) — même format que celui produit par '
          '« Exporter ». Rien n\'est écrit tant que vous n\'avez pas validé '
          'un écran de confirmation.',
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
          label: const Text('Déposer un modèle vide sur le Drive'),
          onPressed: () => exportDirectoryTemplateToDrive(context),
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
            '$_createdCount fiche(s) créée(s), $_updatedCount mise(s) à jour.',
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

  Widget _buildPreview(DirectoryImportPreview preview) {
    final allRows = <Object>[
      ...preview.members,
      ...preview.visitors,
      ...preview.dignitaries,
    ];
    final creations =
        allRows.where((r) => _rowAction(r) == ImportAction.create).length;
    final updates =
        allRows.where((r) => _rowAction(r) == ImportAction.update).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fileName,
          style: const TextStyle(color: BrColors.gold, fontSize: 12),
        ),
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
        Expanded(
          child: ListView(
            children: [
              if (preview.members.isNotEmpty)
                _ImportSection<MemberImportRow>(
                  title: 'MEMBRES',
                  rows: preview.members,
                  nameOf: (r) => '${r.firstName} ${r.lastName}'.trim(),
                  subtitleOf: (r) => r.email,
                  onChanged: () => setState(() {}),
                ),
              if (preview.visitors.isNotEmpty)
                _ImportSection<VisitorImportRow>(
                  title: 'VISITEURS',
                  rows: preview.visitors,
                  nameOf: (r) => '${r.firstName} ${r.lastName}'.trim(),
                  subtitleOf: (r) => r.lodge,
                  onChanged: () => setState(() {}),
                ),
              if (preview.dignitaries.isNotEmpty)
                _ImportSection<DignitaryImportRow>(
                  title: 'DIGNITAIRES',
                  rows: preview.dignitaries,
                  nameOf: (r) => '${r.firstName} ${r.lastName}'.trim(),
                  subtitleOf: (r) => r.lodge,
                  onChanged: () => setState(() {}),
                ),
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

class _ImportSection<T> extends StatelessWidget {
  final String title;
  final List<T> rows;
  final String Function(T) nameOf;
  final String Function(T) subtitleOf;
  final VoidCallback onChanged;
  const _ImportSection({
    required this.title,
    required this.rows,
    required this.nameOf,
    required this.subtitleOf,
    required this.onChanged,
  });

  ImportAction _actionOf(T row) => _rowAction(row as Object);

  bool _hasExisting(T row) => switch (row) {
    MemberImportRow r => r.existing != null,
    VisitorImportRow r => r.existing != null,
    DignitaryImportRow r => r.existing != null,
    _ => false,
  };

  void _setAction(T row, ImportAction action) {
    switch (row) {
      case MemberImportRow r:
        r.action = action;
      case VisitorImportRow r:
        r.action = action;
      case DignitaryImportRow r:
        r.action = action;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrSectionTitle('$title (${rows.length})', icon: Icons.list_alt),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BrCard(
                accent: _hasExisting(row) ? BrColors.gold : BrColors.menuVisiteurs,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameOf(row),
                            style: const TextStyle(color: BrColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          if (subtitleOf(row).isNotEmpty)
                            Text(
                              subtitleOf(row),
                              style: const TextStyle(color: BrColors.muted, fontSize: 11),
                            ),
                          Text(
                            _hasExisting(row) ? 'Doublon détecté' : 'Nouvelle fiche',
                            style: TextStyle(
                              color: _hasExisting(row) ? BrColors.gold : BrColors.menuVisiteurs,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_hasExisting(row))
                      DropdownButton<ImportAction>(
                        value: _actionOf(row),
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: ImportAction.update, child: Text('Mettre à jour')),
                          DropdownMenuItem(value: ImportAction.create, child: Text('Créer quand même')),
                          DropdownMenuItem(value: ImportAction.skip, child: Text('Ignorer')),
                        ],
                        onChanged: (v) => _setAction(row, v ?? ImportAction.update),
                      )
                    else
                      DropdownButton<ImportAction>(
                        value: _actionOf(row),
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: ImportAction.create, child: Text('Créer')),
                          DropdownMenuItem(value: ImportAction.skip, child: Text('Ignorer')),
                        ],
                        onChanged: (v) => _setAction(row, v ?? ImportAction.create),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
