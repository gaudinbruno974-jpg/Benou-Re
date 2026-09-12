// Liste des 4 loges bleues (grille de grandes images) — ouverte depuis le
// pavé « Loges Bleues » de l'accueil Grande Loge. Contrairement à l'accueil
// (identité du Souverain Sanctuaire), cet écran opère bien dans le contexte
// de la Grande Loge de Bourbon (consultation des loges bleues de
// l'obédience) : le titre l'affiche en toutes lettres. Chaque tuile affiche
// le nombre de membres actifs (lecture croisée, voir
// lodge_reader_service.dart) et ouvre un sous-menu Membres / Tenue pour
// cette loge. MMA-Kherou n'en fait plus partie : c'est une tuile directe
// de l'accueil, pas une loge bleue.
import 'package:flutter/material.dart';

import '../services/lodge_reader_service.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_lodge_menu_screen.dart';

class GrandeLogeLodgesListScreen extends StatefulWidget {
  const GrandeLogeLodgesListScreen({super.key});

  @override
  State<GrandeLogeLodgesListScreen> createState() =>
      _GrandeLogeLodgesListScreenState();
}

class _GrandeLogeLodgesListScreenState
    extends State<GrandeLogeLodgesListScreen> {
  final Map<String, int> _counts = {};
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    for (final target in kLodgeReaderTargets) {
      LodgeReaderService.instance
          .memberCount(target)
          .then(
            (count) {
              if (mounted) setState(() => _counts[target.key] = count);
            },
            onError: (e) {
              if (mounted) setState(() => _errors[target.key] = '$e');
            },
          );
    }
  }

  String _subtitle(LodgeReaderTarget target) {
    if (_errors.containsKey(target.key)) return 'Erreur de connexion';
    final count = _counts[target.key];
    if (count == null) return 'Chargement…';
    return '$count membre${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grande Loge de Bourbon')),
      body: GridView(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
        ),
        children: [
          for (final target in kLodgeReaderTargets)
            BrImageMenuTile(
              title: target.label,
              subtitle: _subtitle(target),
              imageAsset: target.logoAsset,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeLodgeMenuScreen(target: target),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
