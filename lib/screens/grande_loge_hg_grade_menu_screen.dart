// Sous-menu par grade (4° à 14°, nomenclature du Collège de Perfection — voir
// kIahMesDegreeNames) d'une section d'IAH-MES : Rituels, Matériel. Rituels :
// la tuile d'un grade ouvre son dossier Drive quand son identifiant est
// renseigné (kIahMesRituelsFolderIds, même principe que les loges bleues —
// library_screen.dart), sinon l'écran « à venir ». Matériel : « à venir ».
// L'arborescence Drive se crée depuis le menu IAH-MES (voir
// grande_loge_hg_menu_screen.dart et DriveService.ensureFolderTree).
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart'
    show kIahMesDegreeNames, kIahMesRituelsFolderIds;
import '../services/url_opener.dart';
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

  Future<void> _openFolder(BuildContext context, String folderId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openExternalUrl(
        'https://drive.google.com/drive/folders/$folderId?usp=drive_link',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le dossier Drive.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$section — ${body.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in kIahMesDegreeNames.entries)
            Builder(
              builder: (context) {
                final folderId = section == 'Rituels'
                    ? kIahMesRituelsFolderIds[entry.key]
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BrMenuTile(
                    title: '${entry.key}° — ${entry.value}',
                    subtitle: folderId == null ? 'À venir' : 'Dossier Drive',
                    icon: Icons.workspace_premium_outlined,
                    color: BrColors.gold,
                    onTap: folderId != null
                        ? () => _openFolder(context, folderId)
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GrandeLogeComingSoonScreen(
                                title:
                                    '$section — ${entry.key}° ${entry.value} — '
                                    '${body.label}',
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
