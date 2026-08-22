// Vérification de l'inventaire du matériel de Loge : parcourt la liste de
// référence, chaque article se marque Conforme / Manquant / Endommagé avec
// un commentaire optionnel. Accessible à tout membre connecté, sans lien
// avec une tenue.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory_check.dart';
import '../models/inventory_item.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

/// Couleur d'accent d'une ligne — neutre tant qu'aucun statut n'a été
/// choisi : « Conforme » ne s'affiche en vert qu'après une action humaine
/// explicite, jamais par défaut.
Color _statusColor(String? status) {
  switch (status) {
    case kCheckManquant:
      return BrColors.menuTresorerie;
    case kCheckEndommage:
      return BrColors.error;
    case kCheckConforme:
      return BrColors.menuVisiteurs;
    default:
      return BrColors.muted;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case kCheckManquant:
      return Icons.remove_circle_outline;
    case kCheckEndommage:
      return Icons.warning_amber_outlined;
    default:
      return Icons.check_circle_outline;
  }
}

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

class InventoryCheckScreen extends StatefulWidget {
  const InventoryCheckScreen({super.key});

  @override
  State<InventoryCheckScreen> createState() => _InventoryCheckScreenState();
}

class _InventoryCheckScreenState extends State<InventoryCheckScreen> {
  final Map<String, String?> _status = {};
  final Map<String, TextEditingController> _comments = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// `null` tant que personne n'a coché le statut de l'article — pas de
  /// repli automatique sur « Conforme », qui doit rester une action humaine.
  String? _statusFor(String id) => _status[id];

  TextEditingController _commentFor(String id) =>
      _comments.putIfAbsent(id, () => TextEditingController());

  /// Seuls les articles explicitement pointés sont enregistrés dans la
  /// vérification : un article non touché n'est ni « Conforme » ni compté,
  /// il reste simplement absent de ce contrôle.
  Future<void> _save(List<InventoryItem> items) async {
    final state = context.read<AppState>();
    setState(() => _saving = true);
    final results = <String, InventoryCheckResult>{
      for (final item in items)
        if (_statusFor(item.id) != null)
          item.id: InventoryCheckResult(
            status: _statusFor(item.id)!,
            comment: _commentFor(item.id).text.trim(),
          ),
    };
    final check = InventoryCheck(
      id: 'chk_${DateTime.now().millisecondsSinceEpoch}',
      performedAt: DateTime.now().toIso8601String(),
      performedByName: state.currentUser?.fullName ?? '',
      results: results,
    );
    await state.submitInventoryCheck(check);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vérification enregistrée.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = [...state.inventoryItems]
      ..sort((a, b) {
        final c = a.category.compareTo(b.category);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    final checkedCount = items.where((i) => _statusFor(i.id) != null).length;
    final allChecked = items.isNotEmpty && checkedCount == items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérifier l\'inventaire')),
      body: Column(
        children: [
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(
                '$checkedCount / ${items.length} article(s) vérifié(s)',
                style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              children: [
                for (final item in items) _CheckRow(
                  item: item,
                  status: _statusFor(item.id),
                  commentController: _commentFor(item.id),
                  onStatusChanged: (s) => setState(() => _status[item.id] = s),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  allChecked
                      ? 'Enregistrer la vérification'
                      : 'Pointez tous les articles ($checkedCount/${items.length})',
                ),
                onPressed:
                    _saving || !allChecked ? null : () => _save(items),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final InventoryItem item;
  final String? status;
  final TextEditingController commentController;
  final ValueChanged<String> onStatusChanged;
  const _CheckRow({
    required this.item,
    required this.status,
    required this.commentController,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: _statusColor(status),
        padding: const EdgeInsets.all(14),
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
            if (item.category.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.category,
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (item.quantity.isNotEmpty)
                  BrBadge(label: 'Qté ${item.quantity}', color: BrColors.teal),
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
                style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in kInventoryCheckStatuses)
                  ChoiceChip(
                    label: Text(s),
                    avatar: Icon(_statusIcon(s), size: 16, color: status == s
                        ? Colors.white
                        : _statusColor(s)),
                    selected: status == s,
                    onSelected: (_) => onStatusChanged(s),
                    selectedColor: _statusColor(s),
                    labelStyle: TextStyle(
                      color: status == s ? Colors.white : BrColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: BrColors.backgroundDark.withValues(alpha: 0.5),
                    side: BorderSide(color: _statusColor(s).withValues(alpha: 0.45)),
                  ),
              ],
            ),
            if (status == kCheckManquant || status == kCheckEndommage) ...[
              const SizedBox(height: 10),
              TextField(
                controller: commentController,
                style: const TextStyle(color: BrColors.text),
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
