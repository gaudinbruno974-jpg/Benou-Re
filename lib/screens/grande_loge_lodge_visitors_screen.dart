// Consultation en lecture seule du répertoire des visiteurs d'une loge,
// depuis le flavor Grande Loge — lecture croisée (voir lodge_reader_service.dart).
import 'package:flutter/material.dart';

import '../models/visitor.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _visitors = null;
      _error = null;
    });
    try {
      final visitors =
          await LodgeReaderService.instance.visitorsOf(widget.target);
      if (mounted) setState(() => _visitors = visitors);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visitors?.where((v) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return v.fullName.toLowerCase().contains(q) ||
          v.lodge.toLowerCase().contains(q);
    }).toList();

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
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                hintText: 'Rechercher un nom ou une loge…',
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
                              child: Text('Aucun visiteur.',
                                  style: TextStyle(color: BrColors.muted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _VisitorCard(visitor: filtered[i]),
                            ),
            ),
          ],
        ),
      ),
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
                  color: BrColors.text, fontWeight: FontWeight.w600, fontSize: 15),
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
