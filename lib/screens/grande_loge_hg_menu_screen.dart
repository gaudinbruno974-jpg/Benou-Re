// Sous-menu générique d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) —
// contrairement aux 4 loges bleues, ces corps n'ont pas encore de données
// propres (pas de projet Firebase, pas de LodgeReaderTarget) : chaque tuile
// ouvre donc un écran « à venir » en attendant leur construction.
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_coming_soon_screen.dart';

class _HgMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  const _HgMenuItem(this.title, this.icon, this.color);
}

const List<_HgMenuItem> _kHgMenuItems = [
  _HgMenuItem('Tenues', Icons.event_outlined, BrColors.teal),
  _HgMenuItem('Membres', Icons.people_outline, BrColors.gold),
  _HgMenuItem('Visiteurs', Icons.shield_outlined, BrColors.menuVisiteurs),
  _HgMenuItem('Dignitaires', Icons.workspace_premium_outlined, BrColors.violet),
  _HgMenuItem('Instructions', Icons.school_outlined, BrColors.menuInstruction),
  _HgMenuItem(
    'Rapport pour la Grande Loge',
    Icons.summarize_outlined,
    BrColors.menuArchitecture,
  ),
];

class GrandeLogeHgMenuScreen extends StatelessWidget {
  final String title;
  const GrandeLogeHgMenuScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in _kHgMenuItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BrMenuTile(
                title: item.title,
                subtitle: 'À venir',
                icon: item.icon,
                color: item.color,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeComingSoonScreen(
                      title: '${item.title} — $title',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
