// Registre des Tenues extérieures reçues (Bureau) : liste triée par date,
// avec bascule automatique vers l'historique (« Invitations passées ») dès
// que la date est dépassée — voir ExternalSession.isPast. Réservé au
// Vénérable Maître, au Secrétaire et aux administrateurs (canEditSessions),
// même droit que pour créer/modifier une tenue de la Loge.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/external_session.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'external_session_detail_screen.dart';
import 'external_session_edit_screen.dart';

class ExternalSessionsScreen extends StatelessWidget {
  const ExternalSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sessions = [...state.externalSessions];
    final upcoming = sessions.where((s) => !s.isPast).toList();
    final past = sessions.where((s) => s.isPast).toList().reversed.toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tenues extérieures'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'À venir'),
              Tab(text: 'Invitations passées'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: BrColors.teal,
          icon: const Icon(Icons.add),
          label: const Text('Invitation reçue'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExternalSessionEditScreen()),
          ),
        ),
        body: TabBarView(
          children: [
            _ExternalSessionList(sessions: upcoming, emptyText: 'Aucune invitation à venir.'),
            _ExternalSessionList(sessions: past, emptyText: 'Aucune invitation passée.'),
          ],
        ),
      ),
    );
  }
}

class _ExternalSessionList extends StatelessWidget {
  final List<ExternalSession> sessions;
  final String emptyText;
  const _ExternalSessionList({required this.sessions, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(emptyText, style: const TextStyle(color: BrColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
      itemCount: sessions.length,
      separatorBuilder: (context, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = sessions[i];
        return BrCard(
          accent: s.isPast ? BrColors.muted : BrColors.gold,
          padding: const EdgeInsets.all(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExternalSessionDetailScreen(externalSessionId: s.id),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.organizingLodge.isEmpty ? '?' : s.organizingLodge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.dateTime == null
                          ? 'Date non définie'
                          : DateFormat('EEEE d MMMM y', 'fr_FR').format(s.dateTime!),
                      style: const TextStyle(color: BrColors.gold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        BrBadge(label: s.degree, color: BrColors.teal),
                        BrBadge(label: s.eventTypeLabel, color: BrColors.menuArchitecture),
                        if (s.attendingMemberIds.isNotEmpty)
                          BrBadge(
                            label: '${s.attendingMemberIds.length} présent(s)',
                            color: BrColors.menuVisiteurs,
                          ),
                        if (s.agapeIds.isNotEmpty)
                          BrBadge(
                            label: '${s.agapeIds.length} aux Agapes',
                            color: BrColors.violet,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BrColors.muted),
            ],
          ),
        );
      },
    );
  }
}
