// Répertoire des visiteurs d'un corps de Hauts Grades (IAH-MES,
// MAA-Kherou) — CRUD complet, même modèle que les loges bleues (Visitor)
// mais dans les collections dédiées du corps (voir hg_body_service.dart).
// Recherche + regroupement Tous / Par Loge / Par Obédience alignés sur
// visitors_screen.dart (loges bleues), demande explicite de l'utilisateur.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/hg_body.dart';
import '../models/member.dart' show kGrades;
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

class GrandeLogeHgVisitorsScreen extends StatefulWidget {
  final HgBody body;
  const GrandeLogeHgVisitorsScreen({super.key, required this.body});

  @override
  State<GrandeLogeHgVisitorsScreen> createState() =>
      _GrandeLogeHgVisitorsScreenState();
}

class _GrandeLogeHgVisitorsScreenState
    extends State<GrandeLogeHgVisitorsScreen> {
  final _search = TextEditingController();
  DirectoryGroupMode _mode = DirectoryGroupMode.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditHgBody(
      context.watch<AppState>().currentUser,
      widget.body,
    );
    return Scaffold(
      appBar: AppBar(title: Text('Visiteurs — ${widget.body.label}')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ajouter'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GrandeLogeHgVisitorEditScreen(body: widget.body),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<Visitor>>(
        stream: HgBodyService.instance.visitorsStream(widget.body),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snap.error}',
                style: const TextStyle(color: BrColors.error),
              ),
            );
          }
          final visitors = snap.data;
          if (visitors == null) {
            return const Center(
              child: CircularProgressIndicator(color: BrColors.gold),
            );
          }
          final filtered =
              visitors
                  .where(
                    (v) => directoryMatches(_search.text, [
                      v.firstName,
                      v.lastName,
                      v.lodge,
                      v.obedience,
                    ]),
                  )
                  .toList()
                ..sort((a, b) => directoryCompare(a.lastName, b.lastName));
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Column(
              children: [
                DirectoryFilterBar(
                  controller: _search,
                  mode: _mode,
                  onModeChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visitors.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun visiteur.',
                            style: TextStyle(color: BrColors.muted),
                          ),
                        )
                      : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun résultat.',
                            style: TextStyle(color: BrColors.muted),
                          ),
                        )
                      : _buildList(filtered, canEdit),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<Visitor> filtered, bool canEdit) {
    if (_mode == DirectoryGroupMode.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 90),
        itemCount: filtered.length,
        separatorBuilder: (context, i) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _visitorCard(filtered[i], canEdit),
      );
    }
    final groups = groupDirectory(
      filtered,
      (v) => _mode == DirectoryGroupMode.byLodge ? v.lodge : v.obedience,
    );
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 90),
      children: [
        for (final g in groups)
          DirectoryGroupSection(
            title: g.key,
            count: g.value.length,
            initiallyExpanded: groups.length == 1,
            children: [
              for (final v in g.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _visitorCard(v, canEdit),
                ),
            ],
          ),
      ],
    );
  }

  Widget _visitorCard(Visitor v, bool canEdit) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: canEdit
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GrandeLogeHgVisitorEditScreen(
                  body: widget.body,
                  visitor: v,
                ),
              ),
            )
          : null,
      child: BrCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            BrAvatar(firstName: v.firstName, lastName: v.lastName, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [v.lodge, v.orient].where((e) => e.isNotEmpty).join(' — '),
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
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
                onPressed: () =>
                    HgBodyService.instance.deleteVisitor(widget.body, v.id),
              ),
          ],
        ),
      ),
    );
  }
}

class GrandeLogeHgVisitorEditScreen extends StatefulWidget {
  final HgBody body;
  final Visitor? visitor;
  const GrandeLogeHgVisitorEditScreen({
    super.key,
    required this.body,
    this.visitor,
  });

  @override
  State<GrandeLogeHgVisitorEditScreen> createState() =>
      _GrandeLogeHgVisitorEditScreenState();
}

class _GrandeLogeHgVisitorEditScreenState
    extends State<GrandeLogeHgVisitorEditScreen> {
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _lodgeCtrl;
  late final TextEditingController _orientCtrl;
  late final TextEditingController _obedienceCtrl;
  late String _civilite;
  late String _grade;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visitor;
    _firstNameCtrl = TextEditingController(text: v?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: v?.lastName ?? '');
    _lodgeCtrl = TextEditingController(text: v?.lodge ?? '');
    _orientCtrl = TextEditingController(text: v?.orient ?? '');
    _obedienceCtrl = TextEditingController(text: v?.obedience ?? '');
    _civilite = v?.civilite.isNotEmpty == true ? v!.civilite : kFrere;
    _grade = v?.grade.isNotEmpty == true ? v!.grade : kGrades.last;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _lodgeCtrl.dispose();
    _orientCtrl.dispose();
    _obedienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lastNameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final v = Visitor(
        id: widget.visitor?.id ?? '',
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        civilite: _civilite,
        grade: _grade,
        lodge: _lodgeCtrl.text.trim(),
        orient: _orientCtrl.text.trim(),
        obedience: _obedienceCtrl.text.trim(),
      );
      await HgBodyService.instance.saveVisitor(widget.body, v);
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
          widget.visitor == null ? 'Ajouter un visiteur' : 'Modifier',
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
                DropdownButtonFormField<String>(
                  initialValue: _grade,
                  decoration: const InputDecoration(labelText: 'Grade / degré'),
                  items: [
                    for (final g in kGrades)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) => setState(() => _grade = v ?? _grade),
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
                  controller: _orientCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Orient'),
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
