// Accueil du flavor Grande Loge de Bourbon (utilisé par le Souverain
// Sanctuaire Traditionnel de La Réunion — voir l'image de fond de
// login_screen.dart) — accueil nominatif par rôle, puis un menu de pavés
// (même style que le Parvis des loges bleues, voir BrMenuTile) : « Loges
// Bleues » ouvre la liste des 4 loges, avec en plus MMA-Kherou et la
// recherche par degré à travers les 4 loges
// (grande_loge_lodges_list_screen.dart) ; IAH-MES ouvre un écran « à
// venir » en attendant son propre contenu. Pas de pavé « Souverain
// Sanctuaire » : toute cette page le représente déjà.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
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
    final state = context.watch<AppState>();
    final user = state.currentUser;
    final roleLabel = kGrandeLogeRoleLabels[user?.role ?? ''] ??
        (user?.function.isNotEmpty == true ? user!.function : 'Compte');

    return Scaffold(
      appBar: AppBar(
        title: Text(LodgeConfig.current.name),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          BrCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_outlined,
                    color: BrColors.gold, size: 40),
                const SizedBox(height: 16),
                Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName
                      : 'Bienvenue',
                  style: const TextStyle(
                    color: BrColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  roleLabel,
                  style: const TextStyle(color: BrColors.muted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const BrSectionTitle('VOTRE ESPACE DE TRAVAIL',
              icon: Icons.workspaces_outline),
          const SizedBox(height: 16),
          BrMenuTile(
            title: 'Loges Bleues',
            subtitle: 'Consulter les 4 loges',
            icon: Icons.people_outline,
            color: BrColors.gold,
            imageAsset: 'assets/GLDB.png',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GrandeLogeLodgesListScreen(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          BrMenuTile(
            title: 'IAH-MES',
            subtitle: 'Atelier 4°-14°',
            icon: Icons.workspace_premium_outlined,
            color: BrColors.menuInstruction,
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
