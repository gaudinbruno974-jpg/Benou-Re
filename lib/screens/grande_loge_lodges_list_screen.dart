// Liste des 4 loges (pavés, style Parvis) — ouverte depuis le pavé
// « Membres » de l'accueil Grande Loge. Chaque pavé affiche le nombre de
// membres actifs (lecture croisée, voir lodge_reader_service.dart) et
// ouvre la consultation détaillée de cette loge.
import 'package:flutter/material.dart';

import '../services/lodge_reader_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_lodge_members_screen.dart';

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

  String _subtitle(LodgeReaderTarget target) {
    if (_errors.containsKey(target.key)) return 'Erreur de connexion';
    final count = _counts[target.key];
    if (count == null) return 'Chargement…';
    return '$count membre${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loges Bleues')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          for (final target in kLodgeReaderTargets)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrMenuTile(
                title: target.label,
                subtitle: _subtitle(target),
                icon: Icons.account_balance_outlined,
                imageAsset: target.logoAsset,
                color: _errors.containsKey(target.key)
                    ? BrColors.error
                    : BrColors.gold,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GrandeLogeLodgeMembersScreen(target: target),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
