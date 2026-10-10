// Effectif d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) — CRUD complet,
// pas une simple consultation en lecture croisée (contrairement aux 4 loges
// bleues) : ces corps vivent dans le projet grande-loge-bourbon lui-même,
// voir hg_body_service.dart. Édition réservée aux rôles autorisés pour ce
// corps précis (voir canEditHgBody, models/hg_body.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../services/directory_xlsx_service.dart';
import '../services/hg_body_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_hg_directory_import_screen.dart';
import 'grande_loge_hg_maakherou_member_sync_actions.dart';
import 'hg_directory_export_actions.dart';

class GrandeLogeHgMembersScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgMembersScreen({super.key, required this.body});

  // Synchro des membres MAA-Kherou (Maîtres des 4 loges bleues) : réservée
  // à ce seul compte, comme la synchro équivalente sur Bénou Ré — voir
  // drive_access_sync_screen.dart.
  static const _memberSyncOwnerEmail = 'gaudin.bruno974@gmail.com';

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    final canEdit = canEditHgBody(currentUser, body);
    final showMemberSync =
        body.key == kMaaKherou.key &&
        currentUser?.email == _memberSyncOwnerEmail;
    return Scaffold(
      appBar: AppBar(
        title: Text('Membres — ${body.label}'),
        actions: canEdit
            ? [
                if (showMemberSync)
                  IconButton(
                    tooltip:
                        'Synchroniser les membres (Maîtres des 4 loges bleues)',
                    icon: const Icon(Icons.group_add_outlined),
                    onPressed: () => runMaaKherouMemberSync(context),
                  ),
                IconButton(
                  tooltip: 'Exporter (Membres/Visiteurs/Dignitaires) en .xlsx',
                  icon: const Icon(Icons.file_upload_outlined),
                  onPressed: () => exportHgDirectories(context, body),
                ),
                IconButton(
                  tooltip: 'Importer depuis un classeur .xlsx',
                  icon: const Icon(Icons.file_download_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GrandeLogeHgDirectoryImportScreen(
                        body: body,
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgMemberEditScreen(body: body),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<Member>>(
        stream: HgBodyService.instance.membersStream(body),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snap.error}',
                style: const TextStyle(color: BrColors.error),
              ),
            );
          }
          final members = snap.data;
          if (members == null) {
            return const Center(
              child: CircularProgressIndicator(color: BrColors.gold),
            );
          }
          if (members.isEmpty) {
            return const Center(
              child: Text(
                'Aucun membre.',
                style: TextStyle(color: BrColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
            itemCount: members.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final m = members[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: canEdit
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GrandeLogeHgMemberEditScreen(
                            body: body,
                            member: m,
                          ),
                        ),
                      )
                    : null,
                child: BrCard(
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
                                if (m.hautsGradesDegree.trim().isNotEmpty)
                                  BrBadge(
                                    label: m.hautsGradesDegree.trim(),
                                    color: BrColors.gold,
                                  ),
                                if (m.function.isNotEmpty &&
                                    m.function != 'Aucun')
                                  BrBadge(
                                    label: m.function,
                                    color: BrColors.teal,
                                    icon: Icons.workspace_premium_outlined,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFFB7185),
                            size: 20,
                          ),
                          onPressed: () => _confirmDelete(context, body, m),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HgBody body,
    Member m,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: Text(m.fullName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HgBodyService.instance.deleteMember(body, m.id);
    }
  }
}

class GrandeLogeHgMemberEditScreen extends StatefulWidget {
  final HgBody body;
  final Member? member;
  const GrandeLogeHgMemberEditScreen({
    super.key,
    required this.body,
    this.member,
  });

  @override
  State<GrandeLogeHgMemberEditScreen> createState() =>
      _GrandeLogeHgMemberEditScreenState();
}

class _GrandeLogeHgMemberEditScreenState
    extends State<GrandeLogeHgMemberEditScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _functionCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _obedienceCtrl;
  late final TextEditingController _motherLodgeCtrl;
  late final TextEditingController _orientCtrl;
  late final TextEditingController _degreeCtrl;
  late String _civilite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _firstNameCtrl = TextEditingController(text: m?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: m?.lastName ?? '');
    _functionCtrl = TextEditingController(text: m?.function ?? '');
    _emailCtrl = TextEditingController(text: m?.email ?? '');
    _phoneCtrl = TextEditingController(text: m?.phone ?? '');
    _obedienceCtrl = TextEditingController(text: m?.obedience ?? '');
    _motherLodgeCtrl = TextEditingController(text: m?.motherLodge ?? '');
    _orientCtrl = TextEditingController(text: m?.orient ?? '');
    _degreeCtrl = TextEditingController(text: m?.hautsGradesDegree ?? '');
    _civilite = m?.civilite.isNotEmpty == true ? m!.civilite : kFrere;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _functionCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _obedienceCtrl.dispose();
    _motherLodgeCtrl.dispose();
    _orientCtrl.dispose();
    _degreeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lastNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final m = Member(
        id: widget.member?.id ?? 'm_${DateTime.now().millisecondsSinceEpoch}',
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        civilite: _civilite,
        function: _functionCtrl.text.trim().isEmpty
            ? 'Aucun'
            : _functionCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        obedience: _obedienceCtrl.text.trim(),
        motherLodge: _motherLodgeCtrl.text.trim(),
        orient: _orientCtrl.text.trim(),
        hautsGradesDegree: _degreeCtrl.text.trim(),
      );
      await HgBodyService.instance.saveMember(widget.body, m);
      if (mounted) Navigator.of(context).pop(m);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.member == null ? 'Ajouter un membre' : 'Modifier'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _civilite,
                  decoration: const InputDecoration(labelText: 'Civilité'),
                  items: [
                    for (final c in kCivilites)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _civilite = v ?? _civilite),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _firstNameCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _lastNameCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _functionCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Office / fonction',
                    hintText: 'ex : Grand Orateur',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _motherLodgeCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Loge mère',
                    hintText: 'ex : R∴L∴ Bénou Ré',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _obedienceCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Obédience'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _orientCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Orient'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _degreeCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Degré (Hauts Grades)',
                    hintText: 'ex : 20',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrColors.text,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
