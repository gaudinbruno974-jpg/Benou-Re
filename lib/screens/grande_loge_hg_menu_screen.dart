// Sous-menu d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) — menu propre à
// chaque corps (voir _kIahMesMenuItems/_kMaaKherouMenuItems), confirmé par
// l'utilisateur : IAH-MES calque le Parvis d'une loge bleue moins Tenues
// extérieures/Trésorerie/Suggestions ; MAA-Kherou en garde un sous-ensemble
// plus restreint. Tenues, Paiement des Agapes, Membres, Visiteurs et
// Dignitaires ont un vrai écran, alignés sur les loges bleues (demande
// explicite de l'utilisateur) ; le reste ouvre un écran « à venir » en
// attendant sa construction.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hg_body.dart';
import '../services/drive_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_coming_soon_screen.dart';
import 'grande_loge_hg_agape_payment_screen.dart';
import 'grande_loge_hg_dignitaries_screen.dart';
import 'grande_loge_hg_grade_menu_screen.dart';
import 'grande_loge_hg_members_screen.dart';
import 'grande_loge_hg_sessions_screen.dart';
import 'grande_loge_hg_visitors_screen.dart';

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
  _HgMenuItem('Rituels', Icons.menu_book_outlined, BrColors.menuRituels),
  _HgMenuItem('Matériel', Icons.inventory_2_outlined, BrColors.menuInventaire),
  _HgMenuItem(
    'Rapport au Souverain Sanctuaire',
    Icons.summarize_outlined,
    BrColors.menuArchitecture,
  ),
  _HgMenuItem('Accès Drive', Icons.sync, BrColors.violet),
];

const List<_HgMenuItem> _kMaaKherouMenuItems = [
  _HgMenuItem('Tenues', Icons.event_outlined, BrColors.teal),
  _HgMenuItem(
    'Paiement des Agapes',
    Icons.restaurant_outlined,
    BrColors.menuTresorerie,
  ),
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

/// Tenues : même écran (générique par HgBody) pour IAH-MES et MAA-Kherou.
bool _hasSessionsScreen(String title, HgBody body) => title == 'Tenues';

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
                subtitle: switch (item.title) {
                  'Membres' => 'Effectif',
                  'Visiteurs' => 'Répertoire',
                  'Dignitaires' => 'Répertoire',
                  'Paiement des Agapes' => 'Médailles & signatures',
                  'Rituels' || 'Matériel' => 'Par grade',
                  _ when _hasSessionsScreen(item.title, body) => 'Convocations',
                  _ => 'À venir',
                },
                icon: item.icon,
                color: item.color,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) {
                      switch (item.title) {
                        case 'Membres':
                          return GrandeLogeHgMembersScreen(body: body);
                        case 'Visiteurs':
                          return GrandeLogeHgVisitorsScreen(body: body);
                        case 'Dignitaires':
                          return GrandeLogeHgDignitariesScreen(body: body);
                        case 'Paiement des Agapes':
                          return GrandeLogeHgAgapePaymentSessionsScreen(
                            body: body,
                          );
                        case 'Rituels' || 'Matériel':
                          return GrandeLogeHgGradeMenuScreen(
                            body: body,
                            section: item.title,
                          );
                      }
                      if (_hasSessionsScreen(item.title, body)) {
                        return GrandeLogeHgSessionsScreen(body: body);
                      }
                      return GrandeLogeComingSoonScreen(
                        title: '${item.title} — ${body.label}',
                      );
                    },
                  ),
                ),
              ),
            ),
          if (body.key == kIahMes.key &&
              canEditHgBody(context.watch<AppState>().currentUser, body))
            BrMenuTile(
              title: "Créer l'arborescence Drive",
              subtitle: 'Dossiers Rituels 4-14',
              icon: Icons.create_new_folder_outlined,
              color: BrColors.violet,
              onTap: () => _createDriveTree(context),
            ),
        ],
      ),
    );
  }
}

/// Crée (sans doublon, relançable) IAH-MES / Rituels 4-14 / un dossier par
/// grade sous la racine SSTR, avec la connexion Google de l'utilisateur.
Future<void> _createDriveTree(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Création des dossiers Drive...')),
  );
  try {
    await DriveService.instance.ensureFolderTree(
      kIahMesRituelsDrivePath,
      iahMesGradeFolderNames(),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Arborescence Drive prête (IAH-MES / Rituels 4-14).'),
        backgroundColor: BrColors.teal,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Erreur Drive : $e')));
  }
}
