// Recherche par degré aux Hauts Grades, à travers les 4 loges à la fois —
// l'objectif qui a motivé le champ Member.hautsGradesDegree et la lecture
// croisée (voir lodge_reader_service.dart). Le champ restant du texte
// libre (pas encore de menu déroulant structuré), la recherche se fait par
// mot-clé plutôt que par seuil numérique « ≥ » — voir discussion de
// conception de cette étape.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class _Result {
  final Member member;
  final String lodgeLabel;
  const _Result({required this.member, required this.lodgeLabel});
}

class GrandeLogeDegreeSearchScreen extends StatefulWidget {
  const GrandeLogeDegreeSearchScreen({super.key});

  @override
  State<GrandeLogeDegreeSearchScreen> createState() =>
      _GrandeLogeDegreeSearchScreenState();
}

class _GrandeLogeDegreeSearchScreenState
    extends State<GrandeLogeDegreeSearchScreen> {
  List<_Result>? _results;
  final Map<String, String> _errors = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _results = null;
      _errors.clear();
    });
    final results = <_Result>[];
    for (final target in kLodgeReaderTargets) {
      try {
        final members = await LodgeReaderService.instance.membersOf(target);
        for (final m in members) {
          if (m.hautsGradesDegree.trim().isNotEmpty) {
            results.add(_Result(member: m, lodgeLabel: target.label));
          }
        }
      } catch (e) {
        _errors[target.key] = '$e';
      }
    }
    results.sort(
      (a, b) => a.member.fullName.toLowerCase().compareTo(
            b.member.fullName.toLowerCase(),
          ),
    );
    if (mounted) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _results?.where((r) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return r.member.fullName.toLowerCase().contains(q) ||
          r.member.hautsGradesDegree.toLowerCase().contains(q) ||
          r.lodgeLabel.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche par degré'),
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
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                hintText: 'Nom, degré ou loge…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tous les membres des 4 loges ayant un degré aux Hauts '
              'Grades renseigné. Recherche par mot-clé — pas encore de '
              'seuil « degré ≥ X » (le champ reste du texte libre).',
              style: const TextStyle(color: BrColors.muted, fontSize: 11.5),
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Loges injoignables : ${_errors.keys.join(', ')}',
                style: const TextStyle(color: BrColors.error, fontSize: 11.5),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: filtered == null
                  ? const Center(
                      child: CircularProgressIndicator(color: BrColors.gold),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun membre avec un degré Hauts Grades '
                            'renseigné pour l\'instant.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: BrColors.muted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: BrCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.member.fullName,
                                      style: const TextStyle(
                                        color: BrColors.text,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${r.lodgeLabel} • ${r.member.grade}',
                                      style: const TextStyle(
                                          color: BrColors.muted, fontSize: 12.5),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.stars_outlined,
                                            color: BrColors.gold, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          r.member.hautsGradesDegree,
                                          style: const TextStyle(
                                            color: BrColors.goldBright,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
