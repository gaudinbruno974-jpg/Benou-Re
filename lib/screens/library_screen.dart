// Bibliothèque : morceaux d'architecture / instructions / rituels
// (porté depuis src/components/LibraryViewer.tsx).
// Les documents sont des dossiers Google Drive, listés par grade. L'accès
// dépend du grade du membre connecté ; les dossiers autorisés s'ouvrent dans
// le navigateur / l'app Drive.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../services/url_opener.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class _DriveFolder {
  final String grade; // kApprenti | kCompagnon | kMaitre
  final String label;
  final String url;
  const _DriveFolder(this.grade, this.label, this.url);
}

/// Pluriel du grade, tel qu'il s'affiche dans le nom du dossier.
const Map<String, String> _gradePlural = {
  kApprenti: 'Apprentis',
  kCompagnon: 'Compagnons',
  kMaitre: 'Maîtres',
};

/// Les dossiers d'architecture s'appellent « Planches » sur le Drive.
String _folderWord(String type) => type == 'Architecture' ? 'Planches' : type;

/// Dossiers Drive du [type] demandé, dans l'ordre des grades. Les identifiants
/// viennent de la configuration de la Loge : chaque loge a ses propres dossiers.
List<_DriveFolder> _foldersFor(String type) {
  final ids = LodgeConfig.current.libraryFolders[type] ?? const {};
  return [
    for (final grade in kGrades)
      if (ids[grade] != null && ids[grade]!.isNotEmpty)
        _DriveFolder(
          grade,
          'Dossier ${_folderWord(type)} - ${_gradePlural[grade] ?? grade}',
          'https://drive.google.com/drive/folders/${ids[grade]}?usp=drive_link',
        ),
  ];
}

class LibraryScreen extends StatelessWidget {
  final String type; // 'Architecture' | 'Instructions' | 'Rituels'
  const LibraryScreen({super.key, required this.type});

  static String _typeNameFr(String t) {
    if (t == 'Architecture') return "Morceaux d'Architecture";
    if (t == 'Rituels') return 'Rituels';
    return 'Instructions';
  }

  bool _isGradeAllowed(String folderGrade, String userGrade) =>
      Session.degreeRank(folderGrade) <= Session.degreeRank(userGrade);

  String _gradeLabel(String g) => g.toUpperCase();

  Color _gradeColor(String g) {
    if (g == kApprenti) return const Color(0xFF60A5FA);
    if (g == kCompagnon) return const Color(0xFF34D399);
    return BrColors.gold;
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openExternalUrl(url);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le dossier Drive.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final userGrade = normalizeGrade(user?.grade ?? kApprenti);
    final folders = _foldersFor(type);

    return Scaffold(
      appBar: AppBar(title: Text(_typeNameFr(type))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          BrCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: BrColors.gold, size: 18),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Les répertoires ci-dessous sont hébergés sur Google Drive et régis '
                    'par vos droits d\'accès initiatiques.',
                    style: TextStyle(
                      color: BrColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const BrSectionTitle('RÉPERTOIRES', icon: Icons.folder_outlined),
          const SizedBox(height: 16),
          ...folders.map((f) {
            final allowed = _isGradeAllowed(f.grade, userGrade);
            final color = allowed ? _gradeColor(f.grade) : BrColors.muted;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrCard(
                accent: color,
                padding: const EdgeInsets.all(16),
                onTap: allowed ? () => _open(context, f.url) : null,
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(BrColors.radiusS),
                        color: color.withValues(alpha: 0.15),
                        border:
                            Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(
                        allowed ? Icons.folder_open : Icons.lock_outline,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.label,
                            style: TextStyle(
                              color: allowed ? Colors.white : BrColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            allowed
                                ? 'Contenu du grade ${_gradeLabel(f.grade)}'
                                : 'Réservé au grade ${_gradeLabel(f.grade)}',
                            style: const TextStyle(
                                color: BrColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (allowed)
                      const Icon(Icons.open_in_new,
                          color: BrColors.teal, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
