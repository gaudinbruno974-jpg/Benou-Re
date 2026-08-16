// Répertoire des visiteurs (porté depuis src/components/VisitorsList.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class VisitorsScreen extends StatelessWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final visitors = [...state.visitors]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final canEdit = canEditSessions(state.currentUser);

    return Scaffold(
      appBar: AppBar(title: const Text('Visiteurs')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => _openEdit(context, null),
            )
          : null,
      body: visitors.isEmpty
          ? const Center(
              child: Text('Aucun visiteur',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
              itemCount: visitors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final v = visitors[i];
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
                              onPressed: () => _openEdit(context, v),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFFB7185), size: 20),
                              onPressed: () => state.deleteVisitor(v.id),
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

  Future<void> _openEdit(BuildContext context, Visitor? visitor) async {
    final state = context.read<AppState>();
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
                _dialogField(lodge, 'Loge'),
                _dialogField(orient, 'Orient'),
                _dialogField(obedience, 'Obédience'),
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
