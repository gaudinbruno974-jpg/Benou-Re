// Bibliothèque : morceaux d'architecture / instructions / rituels
// (porté depuis src/components/LibraryViewer.tsx).
// Les documents sont des dossiers Google Drive, listés par grade. L'accès
// dépend du grade du membre connecté ; les dossiers autorisés s'ouvrent dans
// le navigateur / l'app Drive.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

const MethodChannel _urlChannel = MethodChannel('re.benou.benou_re/urls');

class _DriveFolder {
  final String grade; // 'Apprenti' | 'Compagnon' | 'Maitre'
  final String label;
  final String url;
  const _DriveFolder(this.grade, this.label, this.url);
}

const Map<String, List<_DriveFolder>> _folders = {
  'Architecture': [
    _DriveFolder('Apprenti', 'Dossier Planches - Apprentis',
        'https://drive.google.com/drive/folders/16o7qUPDk31feVoX97NIB-JQezxGn9weV?usp=drive_link'),
    _DriveFolder('Compagnon', 'Dossier Planches - Compagnons',
        'https://drive.google.com/drive/folders/1EyL-gwEMrGy1vIMAWpd9narrne4yQEvZ?usp=drive_link'),
    _DriveFolder('Maitre', 'Dossier Planches - Maîtres',
        'https://drive.google.com/drive/folders/11ez4G3OmCVWNT1BbMDgHfcFYfbKgeqDS?usp=drive_link'),
  ],
  'Rituels': [
    _DriveFolder('Apprenti', 'Dossier Rituels - Apprentis',
        'https://drive.google.com/drive/folders/1HUMlA7LU4p2H2q2irhzR0d9ZbrW0sqhR?usp=drive_link'),
    _DriveFolder('Compagnon', 'Dossier Rituels - Compagnons',
        'https://drive.google.com/drive/folders/1uwoZMDaD6tUp3FkTQAKwXlpEy7H2ETwy?usp=drive_link'),
    _DriveFolder('Maitre', 'Dossier Rituels - Maîtres',
        'https://drive.google.com/drive/folders/1VpvHOaxFNWbkeQHRCvr_pQI-iTSKe3_6?usp=drive_link'),
  ],
  'Instructions': [
    _DriveFolder('Apprenti', 'Dossier Instructions - Apprentis',
        'https://drive.google.com/drive/folders/1qoK7fndJePm3DOxXeElXOowB8oPQB2v9?usp=drive_link'),
    _DriveFolder('Compagnon', 'Dossier Instructions - Compagnons',
        'https://drive.google.com/drive/folders/1n4fmiq36nQMu965bvKlpC5fiytQ_44oU?usp=drive_link'),
    _DriveFolder('Maitre', 'Dossier Instructions - Maîtres',
        'https://drive.google.com/drive/folders/1J_DvRYyy39Myz2t_IYq7Xi516PyUETTi?usp=drive_link'),
  ],
};

class LibraryScreen extends StatelessWidget {
  final String type; // 'Architecture' | 'Instructions' | 'Rituels'
  const LibraryScreen({super.key, required this.type});

  static String _typeNameFr(String t) {
    if (t == 'Architecture') return "Morceaux d'Architecture";
    if (t == 'Rituels') return 'Rituels';
    return 'Instructions';
  }

  bool _isGradeAllowed(String folderGrade, String userGrade) {
    if (folderGrade == 'Apprenti') return true;
    if (folderGrade == 'Compagnon') {
      return userGrade == 'Compagnon' || userGrade == 'Maitre';
    }
    if (folderGrade == 'Maitre') return userGrade == 'Maitre';
    return false;
  }

  String _gradeLabel(String g) => g == 'Maitre' ? 'MAÎTRE' : g.toUpperCase();

  Color _gradeColor(String g) {
    if (g == 'Apprenti') return const Color(0xFF60A5FA);
    if (g == 'Compagnon') return const Color(0xFF34D399);
    return BrColors.gold;
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _urlChannel.invokeMethod<bool>('openUrl', {'url': url});
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le dossier Drive.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final userGrade = user?.grade ?? 'Apprenti';
    final folders = _folders[type] ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(_typeNameFr(type))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Les répertoires ci-dessous sont hébergés sur Google Drive et régis '
            'par vos droits d\'accès initiatiques.',
            style: TextStyle(color: BrColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...folders.map((f) {
            final allowed = _isGradeAllowed(f.grade, userGrade);
            return Card(
              child: ListTile(
                leading: Icon(
                  allowed ? Icons.folder_open : Icons.lock_outline,
                  color: allowed ? _gradeColor(f.grade) : BrColors.muted,
                ),
                title: Text(
                  f.label,
                  style: TextStyle(
                    color: allowed ? Colors.white : BrColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  allowed
                      ? 'Contenu du grade ${_gradeLabel(f.grade)}'
                      : 'Réservé au grade ${_gradeLabel(f.grade)}',
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
                ),
                trailing: allowed
                    ? const Icon(Icons.open_in_new,
                        color: BrColors.teal, size: 18)
                    : null,
                enabled: allowed,
                onTap: allowed ? () => _open(context, f.url) : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}
