// Accueil du flavor Grande Loge de Bourbon, utilisé par le Souverain
// Sanctuaire Traditionnel de La Réunion (voir l'image de fond de
// login_screen.dart) — le titre de la barre du haut reprend donc son nom,
// pas « Grande Loge de Bourbon ». Menu en grille de grandes images (voir
// BrImageMenuTile) plutôt qu'en liste : « Loges Bleues » ouvre la liste des
// 4 loges, avec en plus MMA-Kherou (grande_loge_lodges_list_screen.dart) ;
// IAH-MES ouvre un écran « à venir » en attendant son propre contenu.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_coming_soon_screen.dart';
import 'grande_loge_lodges_list_screen.dart';

/// Libellé lisible d'un rôle Grande Loge, à partir de son code stable
/// (voir [Member.role]) — le code reste la valeur de référence en base,
/// ce libellé n'est qu'un affichage.
const Map<String, String> kGrandeLogeRoleLabels = {
  'sgm': 'Sérénissime Grand Maître',
  'gm': 'Grand Maître',
  'perfection': 'Responsable de la Loge de Perfection',
  'atelier_4_14': 'Responsable de l\'Atelier 4°-14°',
  'atelier_14_18': 'Responsable de l\'Atelier 14°-18°',
  'admin': 'Administrateur',
};

class GrandeLogeHomeScreen extends StatelessWidget {
  const GrandeLogeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Souverain Sanctuaire'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          BrImageMenuTile(
            title: 'Loges Bleues',
            subtitle: 'Consulter les 4 loges',
            imageAsset: 'assets/GLDB.png',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GrandeLogeLodgesListScreen(),
              ),
            ),
          ),
          BrImageMenuTile(
            title: 'IAH-MES',
            subtitle: 'Atelier 4°-14°',
            imageAsset: 'assets/Iah-Mes.jfif',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GrandeLogeComingSoonScreen(
                  title: 'IAH-MES',
                  imageAsset: 'assets/Iah-Mes.jfif',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
