// Sous-menu par grade (4° à 14°, nomenclature du Collège de Perfection — voir
// kIahMesDegreeNames) d'une section d'IAH-MES : Rituels, Matériel. Chaque
// tuile ouvre pour l'instant l'écran « à venir » ; l'arborescence Drive
// correspondante se crée depuis le menu IAH-MES (voir
// grande_loge_hg_menu_screen.dart et DriveService.ensureFolderTree).
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart' show kIahMesDegreeNames;
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_coming_soon_screen.dart';

/// Chemin Drive (sous la racine SSTR) du dossier des rituels d'IAH-MES.
const List<String> kIahMesRituelsDrivePath = ['IAH-MES', 'Rituels 4-14'];

/// Noms des 11 sous-dossiers de grade (« 4° Maître Secret »...).
List<String> iahMesGradeFolderNames() => [
  for (final e in kIahMesDegreeNames.entries) '${e.key}° ${e.value}',
];

class GrandeLogeHgGradeMenuScreen extends StatelessWidget {
  final HgBody body;
  final String section;
  const GrandeLogeHgGradeMenuScreen({
    super.key,
    required this.body,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$section — ${body.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in kIahMesDegreeNames.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BrMenuTile(
                title: '${entry.key}° — ${entry.value}',
                subtitle: 'À venir',
                icon: Icons.workspace_premium_outlined,
                color: BrColors.gold,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeComingSoonScreen(
                      title:
                          '$section — ${entry.key}° ${entry.value} — '
                          '${body.label}',
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
