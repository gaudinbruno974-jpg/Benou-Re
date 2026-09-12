// Sous-menu d'une loge bleue, depuis « Loges Bleues » — consultation en
// lecture croisée (voir lodge_reader_service.dart) de tout ce qu'une loge
// gère : tenues, tenues extérieures, membres, visiteurs, dignitaires,
// bibliothèque (Architecture/Instructions/Rituels) et rapport d'activité.
import 'package:flutter/material.dart';

import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_lodge_activity_report_screen.dart';
import 'grande_loge_lodge_dignitaries_screen.dart';
import 'grande_loge_lodge_external_sessions_screen.dart';
import 'grande_loge_lodge_library_screen.dart';
import 'grande_loge_lodge_members_screen.dart';
import 'grande_loge_lodge_sessions_screen.dart';
import 'grande_loge_lodge_visitors_screen.dart';

class GrandeLogeLodgeMenuScreen extends StatelessWidget {
  final LodgeReaderTarget target;
  const GrandeLogeLodgeMenuScreen({super.key, required this.target});

  void _open(BuildContext context, Widget Function() builder) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => builder()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(target.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrMenuTile(
            title: 'Tenues',
            subtitle: 'Historique des tenues',
            icon: Icons.event_outlined,
            color: BrColors.teal,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeSessionsScreen(target: target),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Tenues extérieures',
            subtitle: 'Reçues par la loge',
            icon: Icons.outbound_outlined,
            color: BrColors.gold,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeExternalSessionsScreen(target: target),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Membres',
            subtitle: 'Effectif de la loge',
            icon: Icons.people_outline,
            color: BrColors.gold,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeMembersScreen(target: target),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Visiteurs',
            subtitle: 'Répertoire',
            icon: Icons.shield_outlined,
            color: BrColors.menuVisiteurs,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeVisitorsScreen(target: target),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Dignitaires',
            subtitle: 'Répertoire',
            icon: Icons.workspace_premium_outlined,
            color: BrColors.violet,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeDignitariesScreen(target: target),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: "Morceaux d'architecture",
            subtitle: 'Planches et travaux',
            icon: Icons.history_edu,
            color: BrColors.menuArchitecture,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeLibraryScreen(
                target: target,
                type: 'Architecture',
              ),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Instructions',
            subtitle: 'Cahiers de formation',
            icon: Icons.school_outlined,
            color: BrColors.menuInstruction,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeLibraryScreen(
                target: target,
                type: 'Instructions',
              ),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Rituels',
            subtitle: 'Textes sacrés',
            icon: Icons.menu_book_outlined,
            color: BrColors.menuRituels,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeLibraryScreen(
                target: target,
                type: 'Rituels',
              ),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'Rapport pour la Grande Loge',
            subtitle: "Rapport d'activité PDF",
            icon: Icons.summarize_outlined,
            color: BrColors.menuArchitecture,
            onTap: () => _open(
              context,
              () => GrandeLogeLodgeActivityReportScreen(target: target),
            ),
          ),
        ],
      ),
    );
  }
}
