// Liste des tenues (porté partiellement depuis src/components/SessionsList.tsx).
// Lecture + détail. La génération de planche/PDF/Drive reste à porter (voir README).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'emargement_screen.dart';

const _navyBtn = Color(0xFF0C235C);

String formatSessionDate(Session s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date inconnue';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sessions = state.sessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenues')),
      body: sessions.isEmpty
          ? const Center(
              child: Text('Aucune tenue enregistrée',
                  style: TextStyle(color: BrColors.muted)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today,
                        color: BrColors.teal),
                    title: Text(
                      s.title.isNotEmpty ? s.title : 'Tenue au grade d\'${s.degree}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${formatSessionDate(s)}\n${s.type} • ${s.degree} • ${s.presentIds.length} présents',
                      style:
                          const TextStyle(color: BrColors.muted, fontSize: 12),
                    ),
                    isThreeLine: true,
                    trailing: s.isValidated
                        ? const Icon(Icons.verified,
                            color: Color(0xFF34D399), size: 20)
                        : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(session: s)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final present = state.members
        .where((m) => session.presentIds.contains(m.id))
        .toList();
    final excused = state.members
        .where((m) => session.excusedIds.contains(m.id))
        .toList();
    final visitors = state.visitors
        .where((v) => session.visitorIds.contains(v.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(session.title.isNotEmpty ? session.title : 'Tenue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoRow('Date', formatSessionDate(session)),
          _infoRow('Type', session.type),
          _infoRow('Degré', session.degree),
          _infoRow('Lieu', session.location.isNotEmpty ? session.location : '—'),
          _infoRow('Tronc de la Veuve', '${session.troncAmount} €'),
          _infoRow('Clôture', session.closingTime),
          const SizedBox(height: 16),
          _section('Membres présents (${present.length})',
              present.map((m) => m.fullName).toList()),
          _section('Membres excusés (${excused.length})',
              excused.map((m) => m.fullName).toList()),
          _section('Visiteurs (${visitors.length})',
              visitors.map((v) => '${v.fullName} — ${v.lodge}').toList()),
          const SizedBox(height: 20),
          const Text('DOCUMENTS',
              style: TextStyle(
                  color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: BrColors.goldBright,
                side: const BorderSide(color: BrColors.gold)),
            icon: const Icon(Icons.draw_outlined, size: 18),
            label: const Text('Émargement / signatures'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmargementScreen(sessionId: session.id),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: BrColors.teal),
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: const Text("Feuille de présence (PDF)"),
            onPressed: () => _openPdf(
              context,
              'Emargement',
              () => buildEmargementPdf(session, state.members, state.visitors),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navyBtn),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Convocation / ordre du jour (PDF)'),
            onPressed: () => _openPdf(
              context,
              'Convocation',
              () => buildConvocationPdf(session, _chrono(session)),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF701A75)),
            icon: const Icon(Icons.history_edu, size: 18),
            label: const Text('Planche tracée (PDF)'),
            onPressed: () => _openPdf(
              context,
              'PlancheTracee',
              () => buildPlancheTraceePdf(
                session,
                state.members,
                state.visitors,
                _chrono(session),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "L'archivage automatique sur Google Drive reste à porter (voir README). Les PDF peuvent être partagés / enregistrés depuis l'aperçu.",
            style: TextStyle(color: BrColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  int _chrono(Session s) {
    if (s.chrono != null) return s.chrono!.toInt();
    final n = int.tryParse((s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''));
    return n ?? 0;
  }

  Future<void> _openPdf(BuildContext context, String prefix,
      Future<List<int>> Function() builder) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await builder();
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: '${prefix}_tenue.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur PDF : $e')),
      );
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    color: BrColors.gold, fontWeight: FontWeight.w600)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(color: BrColors.text))),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('Néant',
                style: TextStyle(color: BrColors.muted, fontSize: 13))
          else
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $e',
                      style:
                          const TextStyle(color: BrColors.text, fontSize: 13)),
                )),
        ],
      ),
    );
  }
}
