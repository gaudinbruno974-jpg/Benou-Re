// Répertoire des dignitaires (miroir de visitors_screen.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/preferred_contact.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';
import 'directory_export_actions.dart';
import 'directory_import_screen.dart';

class DignitariesScreen extends StatefulWidget {
  const DignitariesScreen({super.key});

  @override
  State<DignitariesScreen> createState() => _DignitariesScreenState();
}

class _DignitariesScreenState extends State<DignitariesScreen> {
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
        state.dignitaries
            .where(
              (d) => directoryMatches(_search.text, [
                d.firstName,
                d.lastName,
                d.lodge,
                d.obedience,
              ]),
            )
            .toList()
          ..sort((a, b) => directoryCompare(a.lastName, b.lastName));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dignitaires'),
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
              child: state.dignitaries.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun dignitaire',
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

  Widget _buildList(List<Dignitary> filtered, bool canEdit) {
    if (_mode == DirectoryGroupMode.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _dignitaryCard(filtered[i], canEdit),
      );
    }
    final groups = groupDirectory(
      filtered,
      (d) => _mode == DirectoryGroupMode.byLodge ? d.lodge : d.obedience,
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
              for (final d in g.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _dignitaryCard(d, canEdit),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dignitaryCard(Dignitary d, bool canEdit) {
    return _DignitaryCard(
      dignitary: d,
      canEdit: canEdit,
      onEdit: () => _openEdit(context, d),
      onDelete: () => context.read<AppState>().deleteDignitary(d.id),
    );
  }

  Future<void> _openEdit(BuildContext context, Dignitary? dignitary) async {
    final state = context.read<AppState>();
    final lodgeSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.lodge,
      for (final d in state.dignitaries) d.lodge,
    ]);
    final obedienceSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.obedience,
      for (final d in state.dignitaries) d.obedience,
    ]);

    final first = TextEditingController(text: dignitary?.firstName ?? '');
    final last = TextEditingController(text: dignitary?.lastName ?? '');
    final title = TextEditingController(text: dignitary?.title ?? '');
    final lodge = TextEditingController(text: dignitary?.lodge ?? '');
    final orient = TextEditingController(text: dignitary?.orient ?? '');
    final obedience = TextEditingController(text: dignitary?.obedience ?? '');
    final email = TextEditingController(text: dignitary?.email ?? '');
    final phone = TextEditingController(text: dignitary?.phone ?? '');
    final protocolRank = TextEditingController(
      text: dignitary?.protocolRank?.toString() ?? '',
    );
    var civilite = dignitary?.civilite ?? '';
    var preferredContact = dignitary?.preferredContact ?? '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BrColors.surface,
          title: Text(dignitary == null ? 'Nouveau dignitaire' : 'Modifier',
              style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(first, 'Prénom'),
                _dialogField(last, 'Nom'),
                _dialogField(title, 'Titre / qualité'),
                DirectoryAutocompleteField(
                  controller: lodge,
                  label: 'Loge d\'origine',
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
                _dialogField(
                  protocolRank,
                  'Rang protocolaire (optionnel, plus petit = annoncé en premier)',
                  keyboardType: TextInputType.number,
                ),
                _civiliteDropdown(
                  civilite,
                  (v) => setDialogState(() => civilite = v),
                ),
                _preferredContactDropdown(
                  preferredContact,
                  (v) => setDialogState(() => preferredContact = v),
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
      final id = dignitary?.id ?? 'd_${DateTime.now().millisecondsSinceEpoch}';
      final d = Dignitary(
        id: id,
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        title: title.text.trim(),
        lodge: lodge.text.trim(),
        orient: orient.text.trim(),
        obedience: obedience.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        civilite: civilite,
        preferredContact: preferredContact,
        protocolRank: int.tryParse(protocolRank.text.trim()),
      );
      if (dignitary == null) {
        await state.addDignitary(d);
      } else {
        await state.updateDignitary(d);
      }
    }
  }

  Widget _dialogField(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
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

  Widget _preferredContactDropdown(
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Canal préféré'),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            dropdownColor: BrColors.surface,
            style: const TextStyle(color: BrColors.text),
            items: [
              for (final c in const ['', ...kPreferredContacts])
                DropdownMenuItem(
                  value: c,
                  child: Text(c.isEmpty ? 'Vide' : c),
                ),
            ],
            onChanged: (v) => onChanged(v ?? value),
          ),
        ),
      ),
    );
  }
}

class _DignitaryCard extends StatelessWidget {
  final Dignitary dignitary;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DignitaryCard({
    required this.dignitary,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d = dignitary;
    return BrCard(
      accent: BrColors.violet,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrAvatar(
            firstName: d.firstName,
            lastName: d.lastName,
            size: 46,
            color: BrColors.violet,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (d.title.isNotEmpty)
                      BrBadge(
                        label: d.title,
                        color: BrColors.violet,
                        icon: Icons.workspace_premium_outlined,
                      ),
                    if (d.lodge.isNotEmpty)
                      BrBadge(
                        label:
                            '${d.lodge}${d.orient.isNotEmpty ? ' (${d.orient})' : ''}',
                        color: BrColors.teal,
                        icon: Icons.shield_outlined,
                      ),
                    if (d.obedience.isNotEmpty)
                      BrBadge(
                        label: d.obedience,
                        color: BrColors.gold,
                        icon: Icons.account_balance_outlined,
                      ),
                    if (d.protocolRank != null)
                      BrBadge(
                        label: 'Rang ${d.protocolRank}',
                        color: BrColors.muted,
                        icon: Icons.format_list_numbered,
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
