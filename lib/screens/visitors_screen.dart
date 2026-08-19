// Répertoire des visiteurs (porté depuis src/components/VisitorsList.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';
import 'directory_export_actions.dart';
import 'directory_import_screen.dart';

class VisitorsScreen extends StatefulWidget {
  const VisitorsScreen({super.key});

  @override
  State<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends State<VisitorsScreen> {
  final _search = TextEditingController();
  DirectoryGroupMode _mode = DirectoryGroupMode.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canEdit = canEditSessions(state.currentUser);
    final filtered =
        state.visitors
            .where(
              (v) => directoryMatches(_search.text, [
                v.firstName,
                v.lastName,
                v.lodge,
                v.obedience,
              ]),
            )
            .toList()
          ..sort((a, b) => directoryCompare(a.lastName, b.lastName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visiteurs'),
        actions: canEdit
            ? [
                IconButton(
                  tooltip: 'Exporter (Membres/Visiteurs/Dignitaires) vers le Drive',
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: () => exportDirectoriesToDrive(context),
                ),
                IconButton(
                  tooltip: 'Importer depuis un classeur .xlsx',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DirectoryImportScreen(),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => _openEdit(context, null),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
        child: Column(
          children: [
            DirectoryFilterBar(
              controller: _search,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: state.visitors.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun visiteur',
                        style: TextStyle(color: BrColors.muted),
                      ),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun résultat.',
                        style: TextStyle(color: BrColors.muted),
                      ),
                    )
                  : _buildList(filtered, canEdit),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Visitor> filtered, bool canEdit) {
    if (_mode == DirectoryGroupMode.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _visitorCard(filtered[i], canEdit),
      );
    }
    final groups = groupDirectory(
      filtered,
      (v) => _mode == DirectoryGroupMode.byLodge ? v.lodge : v.obedience,
    );
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 90),
      children: [
        for (final g in groups)
          DirectoryGroupSection(
            title: g.key,
            count: g.value.length,
            initiallyExpanded: groups.length == 1,
            children: [
              for (final v in g.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _visitorCard(v, canEdit),
                ),
            ],
          ),
      ],
    );
  }

  Widget _visitorCard(Visitor v, bool canEdit) {
    return _VisitorCard(
      visitor: v,
      canEdit: canEdit,
      onEdit: () => _openEdit(context, v),
      onDelete: () => context.read<AppState>().deleteVisitor(v.id),
    );
  }

  Future<void> _openEdit(BuildContext context, Visitor? visitor) async {
    final state = context.read<AppState>();
    final lodgeSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.lodge,
      for (final d in state.dignitaries) d.lodge,
    ]);
    final obedienceSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.obedience,
      for (final d in state.dignitaries) d.obedience,
    ]);

    final first = TextEditingController(text: visitor?.firstName ?? '');
    final last = TextEditingController(text: visitor?.lastName ?? '');
    final lodge = TextEditingController(text: visitor?.lodge ?? '');
    final orient = TextEditingController(text: visitor?.orient ?? '');
    final obedience = TextEditingController(text: visitor?.obedience ?? '');
    final email = TextEditingController(text: visitor?.email ?? '');
    final phone = TextEditingController(text: visitor?.phone ?? '');
    var civilite = visitor?.civilite ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BrColors.surface,
          title: Text(visitor == null ? 'Nouveau visiteur' : 'Modifier',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(first, 'Prénom'),
                _dialogField(last, 'Nom'),
                DirectoryAutocompleteField(
                  controller: lodge,
                  label: 'Loge',
                  suggestions: lodgeSuggestions,
                ),
                _dialogField(orient, 'Orient'),
                DirectoryAutocompleteField(
                  controller: obedience,
                  label: 'Obédience',
                  suggestions: obedienceSuggestions,
                ),
                _dialogField(email, 'Email'),
                _dialogField(phone, 'Téléphone'),
                _civiliteDropdown(
                  civilite,
                  (v) => setDialogState(() => civilite = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enregistrer')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final id = visitor?.id ?? 'v_${DateTime.now().millisecondsSinceEpoch}';
      final v = Visitor(
        id: id,
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        lodge: lodge.text.trim(),
        orient: orient.text.trim(),
        obedience: obedience.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        function: visitor?.function ?? '',
        civilite: civilite,
      );
      if (visitor == null) {
        await state.addVisitor(v);
      } else {
        await state.updateVisitor(v);
      }
    }
  }

  Widget _dialogField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _civiliteDropdown(String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Civilité'),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: BrColors.surface,
            style: const TextStyle(color: BrColors.text),
            items: [
              for (final c in const ['', ...kCivilites])
                DropdownMenuItem(
                  value: c,
                  child: Text(c.isEmpty ? 'Non renseignée' : c),
                ),
            ],
            onChanged: (v) => onChanged(v ?? value),
          ),
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final Visitor visitor;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _VisitorCard({
    required this.visitor,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    return BrCard(
      accent: const Color(0xFF34D399),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrAvatar(
            firstName: v.firstName,
            lastName: v.lastName,
            size: 46,
            color: const Color(0xFF34D399),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    BrBadge(
                      label:
                          '${v.lodge}${v.orient.isNotEmpty ? ' (${v.orient})' : ''}',
                      color: BrColors.teal,
                      icon: Icons.shield_outlined,
                    ),
                    if (v.obedience.isNotEmpty)
                      BrBadge(
                        label: v.obedience,
                        color: BrColors.violet,
                        icon: Icons.account_balance_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canEdit)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit,
                      color: BrColors.gold, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFFB7185), size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
