// Consultation en lecture seule du répertoire des dignitaires d'une loge,
// depuis le flavor Grande Loge — lecture croisée (voir lodge_reader_service.dart).
// Recherche + regroupement Tous / Par Loge / Par Obédience alignés sur
// dignitaries_screen.dart (loges bleues), demande explicite de l'utilisateur.
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

class GrandeLogeLodgeDignitariesScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeDignitariesScreen({super.key, required this.target});

  @override
  State<GrandeLogeLodgeDignitariesScreen> createState() =>
      _GrandeLogeLodgeDignitariesScreenState();
}

class _GrandeLogeLodgeDignitariesScreenState
    extends State<GrandeLogeLodgeDignitariesScreen> {
  List<Dignitary>? _dignitaries;
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
      _dignitaries = null;
      _error = null;
    });
    try {
      final dignitaries = await LodgeReaderService.instance.dignitariesOf(
        widget.target,
      );
      if (mounted) setState(() => _dignitaries = dignitaries);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _dignitaries == null
        ? null
        : (_dignitaries!
              .where(
                (d) => directoryMatches(_search.text, [
                  d.firstName,
                  d.lastName,
                  d.lodge,
                  d.obedience,
                  d.title,
                ]),
              )
              .toList()
            ..sort((a, b) => directoryCompare(a.lastName, b.lastName)));

    return Scaffold(
      appBar: AppBar(
        title: Text('Dignitaires — ${widget.target.label}'),
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
              hintText: 'Rechercher un nom, un titre ou une loge…',
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
                        (_dignitaries?.isEmpty ?? true)
                            ? 'Aucun dignitaire.'
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

  Widget _buildList(List<Dignitary> filtered) {
    if (_mode == DirectoryGroupMode.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: filtered.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _DignitaryCard(dignitary: filtered[i]),
      );
    }
    final groups = groupDirectory(
      filtered,
      (d) => _mode == DirectoryGroupMode.byLodge ? d.lodge : d.obedience,
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
              for (final d in g.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DignitaryCard(dignitary: d),
                ),
            ],
          ),
      ],
    );
  }
}

class _DignitaryCard extends StatelessWidget {
  final Dignitary dignitary;
  const _DignitaryCard({required this.dignitary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dignitary.fullName,
              style: const TextStyle(
                color: BrColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if (dignitary.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dignitary.title,
                style: const TextStyle(
                  color: BrColors.goldBright,
                  fontSize: 12.5,
                ),
              ),
            ],
            if (dignitary.lodge.isNotEmpty ||
                dignitary.obedience.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (dignitary.lodge.isNotEmpty) dignitary.lodge,
                  if (dignitary.obedience.isNotEmpty) dignitary.obedience,
                ].join(' • '),
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
