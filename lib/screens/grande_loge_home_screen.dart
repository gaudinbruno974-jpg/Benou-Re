// Accueil du flavor Grande Loge de Bourbon — fondation minimale : accueil
// nominatif par rôle, plus un aperçu du nombre de membres actifs des 4
// loges (preuve visible de la lecture croisée, voir lodge_reader_service.dart)
// — pas encore d'écran de consultation détaillée ni de recherche par degré.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/lodge_reader_service.dart';
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

class GrandeLogeHomeScreen extends StatefulWidget {
  const GrandeLogeHomeScreen({super.key});

  @override
  State<GrandeLogeHomeScreen> createState() => _GrandeLogeHomeScreenState();
}

class _GrandeLogeHomeScreenState extends State<GrandeLogeHomeScreen> {
  final Map<String, int> _counts = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    for (final target in kLodgeReaderTargets) {
      LodgeReaderService.instance.memberCount(target).then(
        (count) {
          if (mounted) setState(() => _counts[target.key] = count);
        },
        onError: (e) {
          if (mounted) setState(() => _errors[target.key] = '$e');
        },
      );
    }
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      style:
                          const TextStyle(color: BrColors.muted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BrCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MEMBRES ACTIFS PAR LOGE',
                      style: TextStyle(
                        color: BrColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final target in kLodgeReaderTargets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                target.label,
                                style: const TextStyle(
                                    color: BrColors.text, fontSize: 14),
                              ),
                            ),
                            if (_errors.containsKey(target.key))
                              const Icon(Icons.error_outline,
                                  color: BrColors.error, size: 18)
                            else if (_counts.containsKey(target.key))
                              Text(
                                '${_counts[target.key]}',
                                style: const TextStyle(
                                  color: BrColors.goldBright,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: BrColors.muted),
                              ),
                          ],
                        ),
                      ),
                    const Text(
                      'Lecture seule, via un compte technique dédié par '
                      'loge. Les écrans de consultation détaillée et la '
                      'recherche par degré viendront dans une prochaine '
                      'étape.',
                      style: TextStyle(color: BrColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
