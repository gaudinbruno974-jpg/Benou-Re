// Écran générique « à venir » — pour les entités Grande Loge sans écran
// dédié pour l'instant (MMA-Kherou, Iah-Mes, Souverain Sanctuaire).
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeComingSoonScreen extends StatelessWidget {
  final String title;
  final String? imageAsset;
  const GrandeLogeComingSoonScreen({
    super.key,
    required this.title,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: BrCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageAsset != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BrColors.radiusM),
                    child: Image.asset(imageAsset!, width: 72, height: 72,
                        fit: BoxFit.cover),
                  )
                else
                  const Icon(Icons.hourglass_top_outlined,
                      color: BrColors.gold, size: 40),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                      color: BrColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cet espace n\'est pas encore construit.',
                  style: TextStyle(color: BrColors.muted, fontSize: 13),
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
