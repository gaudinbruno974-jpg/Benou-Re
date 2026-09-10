// Accueil du flavor Grande Loge de Bourbon — fondation minimale : accueil
// nominatif par rôle, rien d'autre à ce stade (pas d'accès croisé aux
// données des 4 loges, pas d'écrans de consultation — voir la planche de
// cette étape).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: BrCard(
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
                const SizedBox(height: 20),
                const Text(
                  'Fondation en place. Les écrans de consultation des '
                  'quatre loges viendront dans une prochaine étape.',
                  style: TextStyle(color: BrColors.muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
