// Consultation en lecture seule des tenues d'une loge, depuis le flavor
// Grande Loge — lecture croisée (voir lodge_reader_service.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

String _formatSessionDate(Session s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date non définie';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

class GrandeLogeLodgeSessionsScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeSessionsScreen({super.key, required this.target});

  @override
  State<GrandeLogeLodgeSessionsScreen> createState() =>
      _GrandeLogeLodgeSessionsScreenState();
}

class _GrandeLogeLodgeSessionsScreenState
    extends State<GrandeLogeLodgeSessionsScreen> {
  List<Session>? _sessions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _sessions = null;
      _error = null;
    });
    try {
      final sessions =
          await LodgeReaderService.instance.sessionsOf(widget.target);
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tenues — ${widget.target.label}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text('Erreur : $_error',
                  style: const TextStyle(color: BrColors.error)),
            )
          : _sessions == null
              ? const Center(
                  child: CircularProgressIndicator(color: BrColors.gold),
                )
              : _sessions!.isEmpty
                  ? const Center(
                      child: Text('Aucune tenue.',
                          style: TextStyle(color: BrColors.muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions!.length,
                      itemBuilder: (context, i) =>
                          _SessionCard(session: _sessions![i]),
                    ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatSessionDate(session),
              style: const TextStyle(
                  color: BrColors.text, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              [
                '${Session.degreeOrdinal(session.degreeLabel)} degré',
                session.typeLabel,
              ].join(' • '),
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
            if (session.title.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                session.title,
                style: const TextStyle(color: BrColors.goldBright, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
