// Liste et gestion des membres (porté depuis src/components/MembersList.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../services/directory_xlsx_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'directory_export_actions.dart';
import 'directory_import_screen.dart';
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
      appBar: AppBar(
        title: const Text('Membres'),
        actions: canEdit
            ? [
                IconButton(
                  tooltip: 'Exporter (Membres/Visiteurs/Dignitaires) vers le Drive',
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: () => exportDirectories(context),
                ),
                IconButton(
                  tooltip: 'Importer depuis un classeur .xlsx',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DirectoryImportScreen(
                        category: DirectoryCategory.members,
                      ),
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
      body: members.isEmpty
          ? const Center(
              child: Text('Aucun membre',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
              itemCount: members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = members[i];
                return BrCard(
                  accent: BrColors.forGrade(m.grade),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BrAvatar(
                        firstName: m.firstName,
                        lastName: m.lastName,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                BrGradeBadge(grade: m.grade),
                                BrBadge(
                                  label: m.function == 'Aucun'
                                      ? 'Frère'
                                      : m.function,
                                  color: BrColors.teal,
                                  icon: Icons.workspace_premium_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              m.email,
                              style: const TextStyle(
                                color: BrColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      canEdit
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit,
                                      color: BrColors.gold, size: 20),
                                  onPressed: () => _openEdit(context, m),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline,
                                      color: Color(0xFFFB7185), size: 20),
                                  onPressed: () => _confirmDelete(context, m),
                                ),
                              ],
                            )
                          : _StatusChip(status: m.status),
                    ],
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
    return BrBadge(
      label: status,
      color: active ? const Color(0xFF34D399) : BrColors.muted,
      icon: active ? Icons.check_circle_outline : Icons.pause_circle_outline,
    );
  }
}
