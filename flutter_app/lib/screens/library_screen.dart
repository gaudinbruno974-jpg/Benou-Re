// Bibliothèque : morceaux d'architecture / instructions / rituels
// (porté depuis src/components/LibraryViewer.tsx).
// Les documents proviennent de Google Drive ; l'intégration Drive reste à
// porter (voir README). Écran d'attente en attendant le portage.
import 'package:flutter/material.dart';

import '../theme.dart';

class LibraryScreen extends StatelessWidget {
  final String type; // 'Architecture' | 'Instructions' | 'Rituels'
  const LibraryScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(type)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined,
                  color: BrColors.gold, size: 48),
              const SizedBox(height: 16),
              Text(
                'Bibliothèque « $type »',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "La consultation des documents (stockés sur Google Drive) sera disponible après le portage de l'intégration Drive. Voir le README.",
                textAlign: TextAlign.center,
                style: TextStyle(color: BrColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
