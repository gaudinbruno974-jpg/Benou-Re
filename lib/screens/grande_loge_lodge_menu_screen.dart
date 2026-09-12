// Sous-menu d'une loge bleue, depuis « Loges Bleues » — choix entre la
// consultation des membres et celle des tenues, toutes deux en lecture
// croisée (voir lodge_reader_service.dart).
import 'package:flutter/material.dart';

import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_lodge_members_screen.dart';
import 'grande_loge_lodge_sessions_screen.dart';

class GrandeLogeLodgeMenuScreen extends StatelessWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeMenuScreen({super.key, required this.target});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(target.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrMenuTile(
            title: 'Membres',
            subtitle: 'Effectif de la loge',
            icon: Icons.people_outline,
            color: BrColors.gold,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GrandeLogeLodgeMembersScreen(target: target),
              ),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Tenue',
            subtitle: 'Historique des tenues',
            icon: Icons.event_outlined,
            color: BrColors.teal,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GrandeLogeLodgeSessionsScreen(target: target),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
