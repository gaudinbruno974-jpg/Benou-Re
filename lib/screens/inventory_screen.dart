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
import 'inventory_check_screen.dart';
import 'inventory_history_screen.dart';

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
      appBar: AppBar(title: const Text('Matériel')),
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
            for (final item in items) _ItemCard(item: item, canEdit: canEdit),
        ],
      ),
    );
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

    final name = TextEditingController(text: item?.name ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final quantity = TextEditingController(text: item?.quantity ?? '');
    final lentBy = TextEditingController(text: item?.lentBy ?? '');
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: category.text),
                    optionsBuilder: (v) {
                      if (v.text.trim().isEmpty) return categories;
                      final needle = foldLabel(v.text);
                      return categories
                          .where((c) => foldLabel(c).contains(needle));
                    },
                    onSelected: (v) => category.text = v,
                    fieldViewBuilder: (ctx, fc, fn, onSubmit) {
                      fc.text = category.text;
                      fc.addListener(() => category.text = fc.text);
                      return TextField(
                        controller: fc,
                        focusNode: fn,
                        style: const TextStyle(color: BrColors.text),
                        decoration:
                            const InputDecoration(labelText: 'Catégorie'),
                      );
                    },
                  ),
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
                  _dialogField(lentBy, 'Prêté par (F∴ / S∴)'),
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
      lentBy: property == kInvPropFFSS && lentBy.text.trim().isNotEmpty
          ? lentBy.text.trim()
          : null,
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
                'Importer les 65 articles de référence (Rituel du 1er Degré)',
              ),
              onPressed: () => _importSeed(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _importSeed(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          'Importer la liste de référence ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Les 65 articles extraits du Rituel d\'Ouverture au 1er Degré '
          '(Rite de Memphis-Misraïm) seront ajoutés, avec la propriété '
          '« Loge » par défaut. Vous pourrez ensuite corriger celles qui '
          'sont partagées avec la GLDB ou prêtées par un F∴ / une S∴.',
          style: TextStyle(color: BrColors.muted),
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
    if (confirmed != true) return;
    if (!context.mounted) return;
    final state = context.read<AppState>();
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
                      if (item.category.isNotEmpty)
                        BrBadge(
                          label: item.category,
                          color: BrColors.menuInventaire,
                          icon: Icons.category_outlined,
                        ),
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
