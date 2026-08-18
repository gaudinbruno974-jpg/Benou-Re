// Historique des vérifications de l'inventaire du matériel de Loge : chaque
// vérification est datée, horodatée et attribuée à un membre, sans lien
// avec une tenue.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory_check.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final checks = state.inventoryChecks;
    final itemNames = {
      for (final i in state.inventoryItems) i.id: i.name,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des vérifications')),
      body: checks.isEmpty
          ? const Center(
              child: Text(
                'Aucune vérification enregistrée.',
                style: TextStyle(color: BrColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              itemCount: checks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) =>
                  _CheckCard(check: checks[i], itemNames: itemNames),
            ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final InventoryCheck check;
  final Map<String, String> itemNames;
  const _CheckCard({required this.check, required this.itemNames});

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final flagged = check.results.entries
        .where((e) => e.value.status != kCheckConforme)
        .toList();

    return BrCard(
      padding: const EdgeInsets.all(14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Text(
            _formatDate(check.dateTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              check.performedByName.isNotEmpty
                  ? 'Par ${check.performedByName}'
                  : 'Membre non identifié',
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BrBadge(
                  label: '${check.countConforme} conforme(s)',
                  color: BrColors.menuVisiteurs,
                  icon: Icons.check_circle_outline,
                ),
                if (check.countManquant > 0)
                  BrBadge(
                    label: '${check.countManquant} manquant(s)',
                    color: BrColors.menuTresorerie,
                    icon: Icons.remove_circle_outline,
                  ),
                if (check.countEndommage > 0)
                  BrBadge(
                    label: '${check.countEndommage} endommagé(s)',
                    color: BrColors.error,
                    icon: Icons.warning_amber_outlined,
                  ),
              ],
            ),
            if (flagged.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final entry in flagged)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            entry.value.status == kCheckManquant
                                ? Icons.remove_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 16,
                            color: entry.value.status == kCheckManquant
                                ? BrColors.menuTresorerie
                                : BrColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              itemNames[entry.key] ?? '(article supprimé)',
                              style: const TextStyle(
                                color: BrColors.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            entry.value.status,
                            style: TextStyle(
                              color: entry.value.status == kCheckManquant
                                  ? BrColors.menuTresorerie
                                  : BrColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (entry.value.comment.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 2),
                          child: Text(
                            entry.value.comment,
                            style: const TextStyle(
                              color: BrColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
