// Sous-menu d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) — menu propre à
// chaque corps (voir _kIahMesMenuItems/_kMaaKherouMenuItems), confirmé par
// l'utilisateur : IAH-MES calque le Parvis d'une loge bleue moins Tenues
// extérieures/Trésorerie/Suggestions ; MAA-Kherou en garde un sous-ensemble
// plus restreint. Seule « Membres » a un vrai écran pour l'instant (CRUD
// complet dans le projet grande-loge-bourbon, voir hg_body_service.dart) ;
// le reste ouvre un écran « à venir » en attendant sa construction (prochaine
// étape : Tenues).
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_coming_soon_screen.dart';
import 'grande_loge_hg_members_screen.dart';

class _HgMenuItem {
  final String title;
  final IconData icon;
  final Color color;
  const _HgMenuItem(this.title, this.icon, this.color);
}

const List<_HgMenuItem> _kIahMesMenuItems = [
  _HgMenuItem('Tenues', Icons.event_outlined, BrColors.teal),
  _HgMenuItem(
    'Paiement des Agapes',
    Icons.restaurant_outlined,
    BrColors.menuTresorerie,
  ),
  _HgMenuItem('Membres', Icons.people_outline, BrColors.gold),
  _HgMenuItem('Visiteurs', Icons.shield_outlined, BrColors.menuVisiteurs),
  _HgMenuItem('Dignitaires', Icons.workspace_premium_outlined, BrColors.violet),
  _HgMenuItem(
    "Morceaux d'architecture",
    Icons.history_edu,
    BrColors.menuArchitecture,
  ),
  _HgMenuItem('Instructions', Icons.school_outlined, BrColors.menuInstruction),
  _HgMenuItem('Rituels', Icons.menu_book_outlined, BrColors.menuRituels),
  _HgMenuItem('Matériel', Icons.inventory_2_outlined, BrColors.menuInventaire),
  _HgMenuItem('Statistiques', Icons.query_stats_outlined, BrColors.violet),
  _HgMenuItem(
    'Rapport au Souverain Sanctuaire',
    Icons.summarize_outlined,
    BrColors.menuArchitecture,
  ),
  _HgMenuItem('Accès Drive', Icons.sync, BrColors.violet),
];

const List<_HgMenuItem> _kMaaKherouMenuItems = [
  _HgMenuItem('Tenues', Icons.event_outlined, BrColors.teal),
  _HgMenuItem('Membres', Icons.people_outline, BrColors.gold),
  _HgMenuItem('Visiteurs', Icons.shield_outlined, BrColors.menuVisiteurs),
  _HgMenuItem(
    "Morceaux d'architecture",
    Icons.history_edu,
    BrColors.menuArchitecture,
  ),
  _HgMenuItem('Instructions', Icons.school_outlined, BrColors.menuInstruction),
  _HgMenuItem('Statistiques', Icons.query_stats_outlined, BrColors.violet),
  _HgMenuItem(
    'Rapport au Souverain Sanctuaire',
    Icons.summarize_outlined,
    BrColors.menuArchitecture,
  ),
  _HgMenuItem('Accès Drive', Icons.sync, BrColors.violet),
];

class GrandeLogeHgMenuScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgMenuScreen({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final items = body.key == kIahMes.key
        ? _kIahMesMenuItems
        : _kMaaKherouMenuItems;
    return Scaffold(
      appBar: AppBar(title: Text(body.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BrMenuTile(
                title: item.title,
                subtitle: item.title == 'Membres' ? 'Effectif' : 'À venir',
                icon: item.icon,
                color: item.color,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => item.title == 'Membres'
                        ? GrandeLogeHgMembersScreen(body: body)
                        : GrandeLogeComingSoonScreen(
                            title: '${item.title} — ${body.label}',
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
