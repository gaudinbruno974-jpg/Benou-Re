// Consultation détaillée des membres d'une loge, depuis le flavor Grande
// Loge — lecture croisée en lecture seule (voir lodge_reader_service.dart).
// Pas encore de recherche par degré à travers les 4 loges à la fois (étape
// suivante) : cet écran couvre une loge à la fois.
import 'package:flutter/material.dart';

import '../models/member.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeLodgeMembersScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeMembersScreen({super.key, required this.target});

  @override
  State<GrandeLogeLodgeMembersScreen> createState() =>
      _GrandeLogeLodgeMembersScreenState();
}

class _GrandeLogeLodgeMembersScreenState
    extends State<GrandeLogeLodgeMembersScreen> {
  List<Member>? _members;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _members = null;
      _error = null;
    });
    try {
      final members = await LodgeReaderService.instance.membersOf(widget.target);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _members?.where((m) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return m.fullName.toLowerCase().contains(q) ||
          m.function.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.target.label),
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
                hintText: 'Rechercher un nom ou un office…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text('Erreur : $_error',
                          style: const TextStyle(color: BrColors.error)),
                    )
                  : filtered == null
                      ? const Center(
                          child: CircularProgressIndicator(color: BrColors.gold),
                        )
                      : filtered.isEmpty
                          ? const Center(
                              child: Text('Aucun membre.',
                                  style: TextStyle(color: BrColors.muted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _MemberCard(member: filtered[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final hautsGrades = member.hautsGradesDegree.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              member.fullName,
              style: const TextStyle(
                  color: BrColors.text, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              [
                member.grade,
                if (member.function.isNotEmpty && member.function != 'Aucun')
                  member.function,
              ].join(' • '),
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
            if (hautsGrades.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.stars_outlined,
                      color: BrColors.gold, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Hauts Grades : $hautsGrades',
                    style: const TextStyle(
                        color: BrColors.goldBright, fontSize: 12.5),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
