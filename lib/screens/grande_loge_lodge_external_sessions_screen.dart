// Consultation en lecture seule des tenues extérieures reçues par une loge,
// depuis le flavor Grande Loge — lecture croisée (voir lodge_reader_service.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/external_session.dart';
import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

String _formatDate(ExternalSession s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date non définie';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

class GrandeLogeLodgeExternalSessionsScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeExternalSessionsScreen({super.key, required this.target});

  @override
  State<GrandeLogeLodgeExternalSessionsScreen> createState() =>
      _GrandeLogeLodgeExternalSessionsScreenState();
}

class _GrandeLogeLodgeExternalSessionsScreenState
    extends State<GrandeLogeLodgeExternalSessionsScreen> {
  List<ExternalSession>? _sessions;
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
          await LodgeReaderService.instance.externalSessionsOf(widget.target);
      if (mounted) setState(() => _sessions = sessions);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tenues extérieures — ${widget.target.label}'),
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
                      child: Text('Aucune tenue extérieure.',
                          style: TextStyle(color: BrColors.muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions!.length,
                      itemBuilder: (context, i) =>
                          _ExternalSessionCard(session: _sessions![i]),
                    ),
    );
  }
}

class _ExternalSessionCard extends StatelessWidget {
  final ExternalSession session;
  const _ExternalSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.organizingLodge.isNotEmpty
                  ? session.organizingLodge
                  : 'Loge non renseignée',
              style: const TextStyle(
                  color: BrColors.text, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(session),
              style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
            ),
            if (session.eventTypeLabel.isNotEmpty ||
                session.degree.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (session.degree.isNotEmpty) session.degree,
                  if (session.eventTypeLabel.isNotEmpty) session.eventTypeLabel,
                ].join(' • '),
                style: const TextStyle(color: BrColors.goldBright, fontSize: 12.5),
              ),
            ],
            if (session.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                session.location,
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
