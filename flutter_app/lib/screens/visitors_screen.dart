// Répertoire des visiteurs (porté depuis src/components/VisitorsList.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/visitor.dart';
import '../state/app_state.dart';
import '../theme.dart';

class VisitorsScreen extends StatelessWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final visitors = [...state.visitors]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    return Scaffold(
      appBar: AppBar(title: const Text('Visiteurs')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BrColors.teal,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Ajouter'),
        onPressed: () => _openEdit(context, null),
      ),
      body: visitors.isEmpty
          ? const Center(
              child: Text('Aucun visiteur',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: visitors.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final v = visitors[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield_outlined,
                        color: Color(0xFF34D399)),
                    title: Text(v.fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${v.lodge}${v.orient.isNotEmpty ? ' (${v.orient})' : ''}\n${v.obedience}',
                      style:
                          const TextStyle(color: BrColors.muted, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: BrColors.gold, size: 20),
                          onPressed: () => _openEdit(context, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Color(0xFFFB7185), size: 20),
                          onPressed: () => state.deleteVisitor(v.id),
                        ),
                      ],
                    ),
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
}
