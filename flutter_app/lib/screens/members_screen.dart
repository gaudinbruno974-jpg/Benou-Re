// Liste et gestion des membres (porté depuis src/components/MembersList.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'member_edit_screen.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  bool _canEdit(Member user) {
    final fn = user.function.trim();
    return user.isAdmin ||
        fn.contains('Vénérable Maître') ||
        fn.contains('Secrétaire');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canEdit = _canEdit(state.currentUser!);
    final members = [...state.members]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    return Scaffold(
      appBar: AppBar(title: const Text('Membres')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => _openEdit(context, null),
            )
          : null,
      body: members.isEmpty
          ? const Center(
              child: Text('Aucun membre',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = members[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: BrColors.teal.withValues(alpha: 0.2),
                      child: Text(
                        (m.firstName.isNotEmpty ? m.firstName[0] : '?')
                            .toUpperCase(),
                        style: const TextStyle(color: BrColors.goldBright),
                      ),
                    ),
                    title: Text(m.fullName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${m.grade} • ${m.function == 'Aucun' ? 'Frère' : m.function}\n${m.email}',
                      style:
                          const TextStyle(color: BrColors.muted, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: canEdit
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: BrColors.gold, size: 20),
                                onPressed: () => _openEdit(context, m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFFB7185), size: 20),
                                onPressed: () => _confirmDelete(context, m),
                              ),
                            ],
                          )
                        : _StatusChip(status: m.status),
                  ),
                );
              },
            ),
    );
  }

  void _openEdit(BuildContext context, Member? member) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemberEditScreen(member: member)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Member m) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text('Supprimer ce membre ?',
            style: TextStyle(color: Colors.white)),
        content: Text('${m.fullName} sera définitivement supprimé.',
            style: const TextStyle(color: BrColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Color(0xFFFB7185)))),
        ],
      ),
    );
    if (ok == true) {
      await state.deleteMember(m.id);
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final active = status == 'Actif';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? BrColors.teal : BrColors.muted)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status,
          style: TextStyle(
              color: active ? const Color(0xFF34D399) : BrColors.muted,
              fontSize: 11)),
    );
  }
}
