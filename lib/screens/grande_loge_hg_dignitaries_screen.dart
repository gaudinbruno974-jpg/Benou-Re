// Répertoire des dignitaires d'un corps de Hauts Grades (IAH-MES,
// MAA-Kherou) — CRUD complet, même modèle que les loges bleues (Dignitary)
// mais dans les collections dédiées du corps (voir hg_body_service.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../services/hg_body_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgDignitariesScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgDignitariesScreen({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditHgBody(context.watch<AppState>().currentUser, body);
    return Scaffold(
      appBar: AppBar(title: Text('Dignitaires — ${body.label}')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgDignitaryEditScreen(body: body),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<Dignitary>>(
        stream: HgBodyService.instance.dignitariesStream(body),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snap.error}',
                style: const TextStyle(color: BrColors.error),
              ),
            );
          }
          final dignitaries = snap.data;
          if (dignitaries == null) {
            return const Center(
              child: CircularProgressIndicator(color: BrColors.gold),
            );
          }
          if (dignitaries.isEmpty) {
            return const Center(
              child: Text(
                'Aucun dignitaire.',
                style: TextStyle(color: BrColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
            itemCount: dignitaries.length,
            separatorBuilder: (context, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = dignitaries[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: canEdit
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GrandeLogeHgDignitaryEditScreen(
                            body: body,
                            dignitary: d,
                          ),
                        ),
                      )
                    : null,
                child: BrCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      BrAvatar(
                        firstName: d.firstName,
                        lastName: d.lastName,
                        size: 44,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                d.title,
                                d.lodge,
                              ].where((e) => e.isNotEmpty).join(' — '),
                              style: const TextStyle(
                                color: BrColors.muted,
                                fontSize: 12,
                              ),
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
                          onPressed: () => HgBodyService.instance
                              .deleteDignitary(body, d.id),
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
}

class GrandeLogeHgDignitaryEditScreen extends StatefulWidget {
  final HgBody body;
  final Dignitary? dignitary;
  const GrandeLogeHgDignitaryEditScreen({
    super.key,
    required this.body,
    this.dignitary,
  });

  @override
  State<GrandeLogeHgDignitaryEditScreen> createState() =>
      _GrandeLogeHgDignitaryEditScreenState();
}

class _GrandeLogeHgDignitaryEditScreenState
    extends State<GrandeLogeHgDignitaryEditScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _lodgeCtrl;
  late final TextEditingController _obedienceCtrl;
  late String _civilite;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dignitary;
    _firstNameCtrl = TextEditingController(text: d?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: d?.lastName ?? '');
    _titleCtrl = TextEditingController(text: d?.title ?? '');
    _lodgeCtrl = TextEditingController(text: d?.lodge ?? '');
    _obedienceCtrl = TextEditingController(text: d?.obedience ?? '');
    _civilite = d?.civilite.isNotEmpty == true ? d!.civilite : kFrere;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _titleCtrl.dispose();
    _lodgeCtrl.dispose();
    _obedienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lastNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final d = Dignitary(
        id: widget.dignitary?.id ?? '',
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        civilite: _civilite,
        title: _titleCtrl.text.trim(),
        lodge: _lodgeCtrl.text.trim(),
        obedience: _obedienceCtrl.text.trim(),
      );
      await HgBodyService.instance.saveDignitary(widget.body, d);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.dignitary == null ? 'Ajouter un dignitaire' : 'Modifier',
        ),
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
                  controller: _titleCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Titre / qualité',
                    hintText: 'ex : Grand Maître Adjoint',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _lodgeCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Loge / atelier',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _obedienceCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Obédience'),
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
