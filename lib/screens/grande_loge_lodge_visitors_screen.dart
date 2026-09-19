// Consultation en lecture seule du répertoire des visiteurs d'une loge,
// depuis le flavor Grande Loge — lecture croisée (voir lodge_reader_service.dart).
// Recherche + regroupement Tous / Par Loge / Par Obédience alignés sur
// visitors_screen.dart (loges bleues), demande explicite de l'utilisateur.
import 'package:flutter/material.dart';

import '../models/visitor.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

class GrandeLogeLodgeVisitorsScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeVisitorsScreen({super.key, required this.target});

  @override
  State<GrandeLogeLodgeVisitorsScreen> createState() =>
      _GrandeLogeLodgeVisitorsScreenState();
}

class _GrandeLogeLodgeVisitorsScreenState
    extends State<GrandeLogeLodgeVisitorsScreen> {
  List<Visitor>? _visitors;
  String? _error;
  final _search = TextEditingController();
  DirectoryGroupMode _mode = DirectoryGroupMode.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _visitors = null;
      _error = null;
    });
    try {
      final visitors = await LodgeReaderService.instance.visitorsOf(
        widget.target,
      );
      if (mounted) setState(() => _visitors = visitors);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visitors == null
        ? null
        : (_visitors!
              .where(
                (v) => directoryMatches(_search.text, [
                  v.firstName,
                  v.lastName,
                  v.lodge,
                  v.obedience,
                ]),
              )
              .toList()
            ..sort((a, b) => directoryCompare(a.lastName, b.lastName)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Visiteurs — ${widget.target.label}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DirectoryFilterBar(
              controller: _search,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
              hintText: 'Rechercher un nom ou une loge…',
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        'Erreur : $_error',
                        style: const TextStyle(color: BrColors.error),
                      ),
                    )
                  : filtered == null
                  ? const Center(
                      child: CircularProgressIndicator(color: BrColors.gold),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        (_visitors?.isEmpty ?? true)
                            ? 'Aucun visiteur.'
                            : 'Aucun résultat.',
                        style: const TextStyle(color: BrColors.muted),
                      ),
                    )
                  : _buildList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Visitor> filtered) {
    if (_mode == DirectoryGroupMode.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: filtered.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _VisitorCard(visitor: filtered[i]),
      );
    }
    final groups = groupDirectory(
      filtered,
      (v) => _mode == DirectoryGroupMode.byLodge ? v.lodge : v.obedience,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
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
                  child: _VisitorCard(visitor: v),
                ),
            ],
          ),
      ],
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final Visitor visitor;
  const _VisitorCard({required this.visitor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              visitor.fullName,
              style: const TextStyle(
                color: BrColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (visitor.grade.isNotEmpty) visitor.grade,
                if (visitor.lodge.isNotEmpty) visitor.lodge,
                if (visitor.orient.isNotEmpty) visitor.orient,
              ].join(' • '),
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
            if (visitor.obedience.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                visitor.obedience,
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
