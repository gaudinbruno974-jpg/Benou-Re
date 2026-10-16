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

    final present = dignitariesToAnnounce(session, state.dignitaries);
    final vmName = state.lodgeVmName.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Annonce des Dignitaires')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          if (vmName.isNotEmpty) ...[
            _VmCard(name: vmName),
            const SizedBox(height: 18),
          ],
          if (present.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Aucun dignitaire présent pour cette tenue.',
                style: TextStyle(color: BrColors.muted),
              ),
            )
          else
            for (int i = 0; i < present.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AnnounceCard(dignitary: present[i], order: i + 1),
              ),
        ],
      ),
    );
  }
}

/// Rappel du Vénérable Maître de la loge elle-même — distinct des
/// dignitaires visiteurs annoncés un par un : il n'est pas « annoncé » par
/// le Maître des Cérémonies de la même façon, c'est une info de référence
/// (demande explicite de l'utilisateur).
class _VmCard extends StatelessWidget {
  final String name;
  const _VmCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return BrCard(
      accent: BrColors.gold,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VÉNÉRABLE MAÎTRE DE LA LOGE',
            style: TextStyle(
              color: BrColors.goldBright,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnounceCard extends StatelessWidget {
  final Dignitary dignitary;
  final int order;
  const _AnnounceCard({required this.dignitary, required this.order});

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
                  dignitary.title.isNotEmpty ? dignitary.title : 'Dignitaire',
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
