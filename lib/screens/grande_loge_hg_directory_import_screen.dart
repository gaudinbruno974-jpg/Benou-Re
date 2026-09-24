// Import d'un répertoire (Membres, Visiteurs ou Dignitaires) d'un corps de
// Hauts Grades depuis un classeur .xlsx — même principe que
// directory_import_screen.dart (loges bleues), adapté à HgBodyService au
// lieu d'AppState. Voir directory_xlsx_service.dart pour la détection de
// doublon et la résolution de chaque ligne (100% partagé, aucune donnée
// propre aux loges bleues).
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../services/directory_xlsx_service.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'hg_directory_export_actions.dart';

enum _Step { intro, loading, preview, writing, done, error }

class GrandeLogeHgDirectoryImportScreen extends StatefulWidget {
  final HgBody body;
  final DirectoryCategory category;
  const GrandeLogeHgDirectoryImportScreen({
    super.key,
    required this.body,
    required this.category,
  });

  @override
  State<GrandeLogeHgDirectoryImportScreen> createState() =>
      _GrandeLogeHgDirectoryImportScreenState();
}

class _GrandeLogeHgDirectoryImportScreenState
    extends State<GrandeLogeHgDirectoryImportScreen> {
  _Step _step = _Step.intro;
  String? _errorMessage;
  List<Object> _rows = const [];
  String _fileName = '';
  int _createdCount = 0;
  int _updatedCount = 0;

  String get _categoryLabel => switch (widget.category) {
    DirectoryCategory.members => 'Membres',
    DirectoryCategory.visitors => 'Visiteurs',
    DirectoryCategory.dignitaries => 'Dignitaires',
  };

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
      final List<Object> rows = switch (widget.category) {
        DirectoryCategory.members => parseMemberSheet(
          bytes,
          await HgBodyService.instance.membersOnce(widget.body),
        ),
        DirectoryCategory.visitors => parseVisitorSheet(
          bytes,
          await HgBodyService.instance.visitorsStream(widget.body).first,
        ),
        DirectoryCategory.dignitaries => parseDignitarySheet(
          bytes,
          await HgBodyService.instance.dignitariesStream(widget.body).first,
        ),
      };
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = rows;
        _step = _Step.preview;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Fichier illisible ou format inattendu : $e';
        _step = _Step.error;
      });
    }
  }

  Future<void> _confirmAndWrite() async {
    final toWrite = _rows
        .where((r) => _rowAction(r) != ImportAction.skip)
        .toList();
    final creations = toWrite
        .where((r) => _rowAction(r) == ImportAction.create)
        .length;
    final updates = toWrite
        .where((r) => _rowAction(r) == ImportAction.update)
        .length;

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
          'seront mises à jour dans le répertoire $_categoryLabel. Cette '
          'action écrit directement dans la base de ${widget.body.label}.',
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
    var created = 0;
    var updated = 0;
    var seq = 0;
    String newId(String prefix) =>
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${seq++}';

    for (final row in toWrite) {
      switch (row) {
        case MemberImportRow r:
          final member = r.resolve(() => newId('m'));
          if (member == null) continue;
          await HgBodyService.instance.saveMember(widget.body, member);
          if (r.action == ImportAction.create) {
            created++;
          } else {
            updated++;
          }
        case VisitorImportRow r:
          final visitor = r.resolve(() => newId('v'));
          if (visitor == null) continue;
          await HgBodyService.instance.saveVisitor(widget.body, visitor);
          if (r.action == ImportAction.create) {
            created++;
          } else {
            updated++;
          }
        case DignitaryImportRow r:
          final dignitary = r.resolve(() => newId('d'));
          if (dignitary == null) continue;
          await HgBodyService.instance.saveDignitary(widget.body, dignitary);
          if (r.action == ImportAction.create) {
            created++;
          } else {
            updated++;
          }
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
      appBar: AppBar(title: Text('Importer — $_categoryLabel')),
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
                Text(
                  'Écriture en cours…',
                  style: TextStyle(color: BrColors.muted),
                ),
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
        Text(
          'Sélectionnez un classeur .xlsx contenant une feuille '
          '« $_categoryLabel » — même format que celui produit par '
          '« Exporter » (les autres feuilles éventuellement présentes dans '
          'le fichier ne seront pas lues). Rien n\'est écrit tant que vous '
          'n\'avez pas validé un écran de confirmation.',
          style: const TextStyle(
            color: BrColors.muted,
            fontSize: 13,
            height: 1.4,
          ),
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
          onPressed: () => exportHgDirectoryTemplate(context, widget.body),
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
          const Icon(
            Icons.check_circle_outline,
            color: BrColors.menuVisiteurs,
            size: 40,
          ),
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

  Widget _buildPreview() {
    final creations = _rows
        .where((r) => _rowAction(r) == ImportAction.create)
        .length;
    final updates = _rows
        .where((r) => _rowAction(r) == ImportAction.update)
        .length;

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
            BrBadge(
              label: '$creations création(s)',
              color: BrColors.menuVisiteurs,
            ),
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

ImportAction _rowAction(Object row) => switch (row) {
  MemberImportRow r => r.action,
  VisitorImportRow r => r.action,
  DignitaryImportRow r => r.action,
  _ => ImportAction.skip,
};

bool _rowHasExisting(Object row) => switch (row) {
  MemberImportRow r => r.existing != null,
  VisitorImportRow r => r.existing != null,
  DignitaryImportRow r => r.existing != null,
  _ => false,
};

String _rowName(Object row) => switch (row) {
  MemberImportRow r => '${r.firstName} ${r.lastName}'.trim(),
  VisitorImportRow r => '${r.firstName} ${r.lastName}'.trim(),
  DignitaryImportRow r => '${r.firstName} ${r.lastName}'.trim(),
  _ => '',
};

String _rowSubtitle(Object row) => switch (row) {
  MemberImportRow r => r.email,
  VisitorImportRow r => r.lodge,
  DignitaryImportRow r => r.lodge,
  _ => '',
};

void _setRowAction(Object row, ImportAction action) {
  switch (row) {
    case MemberImportRow r:
      r.action = action;
    case VisitorImportRow r:
      r.action = action;
    case DignitaryImportRow r:
      r.action = action;
  }
}

class _ImportRowCard extends StatelessWidget {
  final Object row;
  final VoidCallback onChanged;
  const _ImportRowCard({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasExisting = _rowHasExisting(row);
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
                    _rowName(row),
                    style: const TextStyle(
                      color: BrColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_rowSubtitle(row).isNotEmpty)
                    Text(
                      _rowSubtitle(row),
                      style: const TextStyle(
                        color: BrColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  Text(
                    hasExisting ? 'Doublon détecté' : 'Nouvelle fiche',
                    style: TextStyle(
                      color: hasExisting
                          ? BrColors.gold
                          : BrColors.menuVisiteurs,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<ImportAction>(
              value: _rowAction(row),
              dropdownColor: BrColors.surface,
              style: const TextStyle(color: BrColors.text, fontSize: 12),
              items: [
                if (hasExisting)
                  const DropdownMenuItem(
                    value: ImportAction.update,
                    child: Text('Mettre à jour'),
                  ),
                DropdownMenuItem(
                  value: ImportAction.create,
                  child: Text(hasExisting ? 'Créer quand même' : 'Créer'),
                ),
                const DropdownMenuItem(
                  value: ImportAction.skip,
                  child: Text('Ignorer'),
                ),
              ],
              onChanged: (v) {
                _setRowAction(
                  row,
                  v ??
                      (hasExisting ? ImportAction.update : ImportAction.create),
                );
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
