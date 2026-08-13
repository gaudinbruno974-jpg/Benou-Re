// Répertoire des dignitaires (miroir de visitors_screen.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dignitary.dart';
import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class DignitariesScreen extends StatelessWidget {
  const DignitariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dignitaries = [...state.dignitaries]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final canEdit = canEditSessions(state.currentUser);

    return Scaffold(
      appBar: AppBar(title: const Text('Dignitaires')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => _openEdit(context, null),
            )
          : null,
      body: dignitaries.isEmpty
          ? const Center(
              child: Text('Aucun dignitaire',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
              itemCount: dignitaries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = dignitaries[i];
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
                              onPressed: () => _openEdit(context, d),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFFB7185), size: 20),
                              onPressed: () => state.deleteDignitary(d.id),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openEdit(BuildContext context, Dignitary? dignitary) async {
    final state = context.read<AppState>();
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              _dialogField(lodge, 'Loge d\'origine'),
              _dialogField(orient, 'Orient'),
              _dialogField(obedience, 'Obédience'),
              _dialogField(email, 'Email'),
              _dialogField(phone, 'Téléphone'),
              _dialogField(
                protocolRank,
                'Rang protocolaire (optionnel, plus petit = annoncé en premier)',
                keyboardType: TextInputType.number,
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
}
