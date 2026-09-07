// Inventaire du matériel de Loge : liste de référence et accès à la
// vérification / l'historique. Module autonome, sans lien avec les tenues.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/inventory_seed_data.dart';
import '../models/inventory_item.dart';
import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';
import 'inventory_check_screen.dart';
import 'inventory_export_actions.dart';
import 'inventory_history_screen.dart';
import 'inventory_import_screen.dart';

Color _propertyColor(String property) {
  switch (property) {
    case kInvPropGLDB:
      return BrColors.violet;
    case kInvPropFFSS:
      return BrColors.menuTresorerie;
    default:
      return BrColors.menuVisiteurs;
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canEdit = canEditSessions(state.currentUser);
    final items = [...state.inventoryItems]
      ..sort((a, b) {
        final c = a.category.compareTo(b.category);
        return c != 0 ? c : a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matériel'),
        actions: canEdit
            ? [
                IconButton(
                  tooltip: 'Exporter en .xlsx',
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: () => exportInventory(context),
                ),
                IconButton(
                  tooltip: 'Importer depuis un classeur .xlsx',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InventoryImportScreen(),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'template':
                        exportInventoryTemplate(context);
                      case 'reimport':
                        _importSeed(context, items);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'template',
                      child: Text('Télécharger un modèle vide (.xlsx)'),
                    ),
                    PopupMenuItem(
                      value: 'reimport',
                      child: Text(
                        'Réimporter la liste de référence (Rituel du 1er Degré)',
                      ),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              onPressed: () => _openEdit(context, null),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.fact_check_outlined,
                  label: 'Vérifier l\'inventaire',
                  color: BrColors.gold,
                  onTap: items.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const InventoryCheckScreen(),
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.history,
                  label: 'Historique',
                  color: BrColors.menuArchitecture,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InventoryHistoryScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const BrSectionTitle('LISTE DE RÉFÉRENCE', icon: Icons.list_alt),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _EmptyState(canEdit: canEdit)
          else
            for (final entry in _groupByCategory(items).entries)
              _CategorySection(
                category: entry.key,
                items: entry.value,
                canEdit: canEdit,
              ),
        ],
      ),
    );
  }

  static Map<String, List<InventoryItem>> _groupByCategory(
    List<InventoryItem> items,
  ) {
    final byCategory = <String, List<InventoryItem>>{};
    for (final item in items) {
      final key = item.category.trim().isEmpty
          ? 'Sans catégorie'
          : item.category.trim();
      byCategory.putIfAbsent(key, () => []).add(item);
    }
    final sortedKeys = byCategory.keys.toList()..sort();
    return {for (final k in sortedKeys) k: byCategory[k]!};
  }

  static Future<void> _openEdit(
    BuildContext context,
    InventoryItem? item,
  ) async {
    final state = context.read<AppState>();
    final categories = state.inventoryItems
        .map((i) => i.category)
        .where((c) => c.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final memberNames = state.members
        .map((m) => m.fullName)
        .where((n) => n.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    var lentByValue = item?.lentBy;
    final lentByOptions = [
      if (lentByValue != null &&
          lentByValue.isNotEmpty &&
          !memberNames.contains(lentByValue))
        lentByValue,
      ...memberNames,
    ];

    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final quantity = TextEditingController(text: item?.quantity ?? '');
    final note = TextEditingController(text: item?.note ?? '');
    var property = item?.property ?? kInvPropLoge;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: BrColors.surface,
          title: Text(
            item == null ? 'Nouvel article' : 'Modifier l\'article',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(name, 'Nom de l\'article'),
                DirectoryAutocompleteField(
                  controller: category,
                  label: 'Catégorie',
                  suggestions: categories,
                ),
                _dialogField(quantity, 'Quantité de référence'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Propriété'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: property,
                        isExpanded: true,
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text),
                        items: [
                          for (final p in kInventoryProperties)
                            DropdownMenuItem(value: p, child: Text(p)),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => property = v ?? property),
                      ),
                    ),
                  ),
                ),
                if (property == kInvPropFFSS)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Prêté par (F∴ / S∴)',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: lentByValue,
                          isExpanded: true,
                          dropdownColor: BrColors.surface,
                          style: const TextStyle(color: BrColors.text),
                          hint: const Text(
                            'Sélectionner un membre',
                            style: TextStyle(color: BrColors.muted),
                          ),
                          items: [
                            for (final n in lentByOptions)
                              DropdownMenuItem(value: n, child: Text(n)),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => lentByValue = v),
                        ),
                      ),
                    ),
                  ),
                _dialogField(note, 'Note (emplacement, précision…)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || name.text.trim().isEmpty) return;

    final id = item?.id ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final result = InventoryItem(
      id: id,
      category: category.text.trim(),
      name: name.text.trim(),
      quantity: quantity.text.trim(),
      property: property,
      lentBy: property == kInvPropFFSS ? lentByValue : null,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    if (item == null) {
      await state.addInventoryItem(result);
    } else {
      await state.updateInventoryItem(result);
    }
  }

  static Widget _dialogField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  /// Importe le jeu de données de référence. Si des articles existent déjà
  /// (import précédent), ils sont d'abord supprimés : la nouvelle liste
  /// remplace toujours l'ancienne plutôt que de s'y ajouter.
  static Future<void> _importSeed(
    BuildContext context,
    List<InventoryItem> existing,
  ) async {
    final replacing = existing.isNotEmpty;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: Text(
          replacing
              ? 'Remplacer la liste de référence ?'
              : 'Importer la liste de référence ?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          replacing
              ? 'Les ${existing.length} article(s) actuellement enregistrés '
                    'seront supprimés et remplacés par les '
                    '${kInventorySeedData.length} articles du Rituel '
                    'd\'Ouverture au 1er Degré (Rite de Memphis-Misraïm), '
                    'propriété « Loge » par défaut.'
              : 'Les ${kInventorySeedData.length} articles extraits du '
                    'Rituel d\'Ouverture au 1er Degré (Rite de '
                    'Memphis-Misraïm) seront ajoutés, avec la propriété '
                    '« Loge » par défaut.',
          style: const TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(replacing ? 'Remplacer' : 'Importer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final state = context.read<AppState>();
    for (final item in existing) {
      await state.deleteInventoryItem(item.id);
    }
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < kInventorySeedData.length; i++) {
      final row = kInventorySeedData[i];
      await state.addInventoryItem(
        InventoryItem(
          id: 'inv_${base}_$i',
          category: row['category'] ?? '',
          name: row['name'] ?? '',
          quantity: row['quantity'] ?? '',
          property: kInvPropLoge,
          note: (row['note'] ?? '').isEmpty ? null : row['note'],
        ),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool canEdit;
  const _EmptyState({required this.canEdit});

  @override
  Widget build(BuildContext context) {
    return BrCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aucun article dans la liste de référence.',
            style: TextStyle(color: BrColors.muted),
          ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download_outlined),
              label: const Text(
                'Importer les articles de référence (Rituel du 1er Degré)',
              ),
              onPressed: () => InventoryScreen._importSeed(context, const []),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BrCard(
      accent: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<InventoryItem> items;
  final bool canEdit;
  const _CategorySection({
    required this.category,
    required this.items,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 10),
            leading: const Icon(
              Icons.folder_outlined,
              color: BrColors.menuInventaire,
            ),
            title: Text(
              category,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${items.length} article(s)',
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
            children: [
              for (final item in items) _ItemCard(item: item, canEdit: canEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  final bool canEdit;
  const _ItemCard({required this.item, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: _propertyColor(item.property),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (item.quantity.isNotEmpty)
                        BrBadge(
                          label: 'Qté ${item.quantity}',
                          color: BrColors.teal,
                        ),
                      BrBadge(
                        label: item.property,
                        color: _propertyColor(item.property),
                      ),
                      if (item.property == kInvPropFFSS &&
                          (item.lentBy ?? '').isNotEmpty)
                        BrBadge(
                          label: 'Prêté par ${item.lentBy}',
                          color: BrColors.menuTresorerie,
                          icon: Icons.person_outline,
                        ),
                    ],
                  ),
                  if ((item.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.note!,
                      style: const TextStyle(
                        color: BrColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canEdit)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.edit,
                      color: BrColors.gold,
                      size: 20,
                    ),
                    onPressed: () => InventoryScreen._openEdit(context, item),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFB7185),
                      size: 20,
                    ),
                    onPressed: () => state.deleteInventoryItem(item.id),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
