// Vue d'annonce des Dignitaires pour une tenue de Hauts Grades — même
// principe que session_dignitaires_announce_screen.dart (loges bleues) :
// pensée pour être consultée d'un coup d'œil juste avant l'entrée en loge
// du Trois Fois Puissant Maître. dignitariesToAnnounce (dignitary.dart) est
// déjà générique (Session + List<Dignitary>) et réutilisé tel quel.
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/session.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgDignitairesAnnounceScreen extends StatelessWidget {
  final HgBody body;
  final Session session;
  const GrandeLogeHgDignitairesAnnounceScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Annonce des Dignitaires')),
      body: StreamBuilder<List<Dignitary>>(
        stream: HgBodyService.instance.dignitariesStream(body),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) {
            return const Center(
              child: CircularProgressIndicator(color: BrColors.gold),
            );
          }
          final present = dignitariesToAnnounce(session, all);
          if (present.isEmpty) {
            return const Center(
              child: Text(
                'Aucun dignitaire présent pour cette tenue.',
                style: TextStyle(color: BrColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            itemCount: present.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, i) =>
                _AnnounceCard(dignitary: present[i], order: i + 1),
          );
        },
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
