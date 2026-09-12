// Consultation en lecture seule du répertoire des dignitaires d'une loge,
// depuis le flavor Grande Loge — lecture croisée (voir lodge_reader_service.dart).
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

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
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _dignitaries = null;
      _error = null;
    });
    try {
      final dignitaries =
          await LodgeReaderService.instance.dignitariesOf(widget.target);
      if (mounted) setState(() => _dignitaries = dignitaries);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _dignitaries?.where((d) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return d.fullName.toLowerCase().contains(q) ||
          d.lodge.toLowerCase().contains(q) ||
          d.title.toLowerCase().contains(q);
    }).toList();

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
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                hintText: 'Rechercher un nom, un titre ou une loge…',
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
                              child: Text('Aucun dignitaire.',
                                  style: TextStyle(color: BrColors.muted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _DignitaryCard(dignitary: filtered[i]),
                            ),
            ),
          ],
        ),
      ),
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
                  color: BrColors.text, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            if (dignitary.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                dignitary.title,
                style: const TextStyle(color: BrColors.goldBright, fontSize: 12.5),
              ),
            ],
            if (dignitary.lodge.isNotEmpty || dignitary.obedience.isNotEmpty) ...[
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
