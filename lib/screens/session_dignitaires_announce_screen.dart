// Vue d'annonce des Dignitaires pour une tenue : pensée pour être consultée
// d'un coup d'œil par le Maître des Cérémonies juste avant l'entrée en loge
// du Vénérable Maître (voir canViewDignitaryAnnounce dans member.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dignitary.dart';
import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class SessionDignitairesAnnounceScreen extends StatelessWidget {
  final String sessionId;
  const SessionDignitairesAnnounceScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => Session(id: sessionId),
    );

    final present = state.dignitaries
        .where((d) => session.dignitaryIds.contains(d.id))
        .toList()
      ..sort((a, b) {
        final ra = a.protocolRank;
        final rb = b.protocolRank;
        if (ra != null && rb != null) {
          final cmp = ra.compareTo(rb);
          if (cmp != 0) return cmp;
        } else if (ra != null) {
          return -1;
        } else if (rb != null) {
          return 1;
        }
        return a.lastName.compareTo(b.lastName);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Annonce des Dignitaires')),
      body: present.isEmpty
          ? const Center(
              child: Text(
                'Aucun dignitaire présent pour cette tenue.',
                style: TextStyle(color: BrColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              itemCount: present.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final d = present[i];
                final role = (session.dignitaryRoles[d.id] ?? '').trim();
                return _AnnounceCard(dignitary: d, order: i + 1, role: role);
              },
            ),
    );
  }
}

class _AnnounceCard extends StatelessWidget {
  final Dignitary dignitary;
  final int order;
  final String role;
  const _AnnounceCard({
    required this.dignitary,
    required this.order,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return BrCard(
      accent: BrColors.violet,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrColors.violet.withValues(alpha: 0.18),
              border: Border.all(color: BrColors.violet.withValues(alpha: 0.5)),
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                color: BrColors.violet,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dignitary.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role.isNotEmpty
                      ? role
                      : (dignitary.title.isNotEmpty
                          ? dignitary.title
                          : 'Dignitaire'),
                  style: const TextStyle(
                    color: BrColors.goldBright,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dignitary.lodge.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dignitary.lodge,
                    style: const TextStyle(color: BrColors.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
