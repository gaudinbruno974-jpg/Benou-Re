// Bibliothèque d'une loge (Morceaux d'architecture / Instructions / Rituels),
// depuis le flavor Grande Loge — pas de collection Firestore ici : ce sont
// des dossiers Google Drive référencés dans la configuration de la loge
// (LodgeConfig.libraryFolders), lue en croisé via
// LodgeReaderService.lodgeConfigOf (voir ce service pour le détail de la
// fusion avec le document `config/settings` réel de la loge). Contrairement
// à library_screen.dart (côté loge bleue), aucun verrou de grade : la
// Grande Loge voit tous les dossiers.
import 'package:flutter/material.dart';

import '../config/lodge_config.dart';
import '../models/member.dart';
import '../services/lodge_reader_service.dart';
import '../services/url_opener.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class _DriveFolder {
  final String grade;
  final String label;
  final String url;
  const _DriveFolder(this.grade, this.label, this.url);
}

const Map<String, String> _gradePlural = {
  kApprenti: 'Apprentis',
  kCompagnon: 'Compagnons',
  kMaitre: 'Maîtres',
};

String _folderWord(String type) => type == 'Architecture' ? 'Planches' : type;

List<_DriveFolder> _foldersFor(LodgeConfig config, String type) {
  final ids = config.libraryFolders[type] ?? const {};
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

String _typeNameFr(String t) {
  if (t == 'Architecture') return "Morceaux d'Architecture";
  if (t == 'Rituels') return 'Rituels';
  return 'Instructions';
}

Color _gradeColor(String g) {
  if (g == kApprenti) return const Color(0xFF60A5FA);
  if (g == kCompagnon) return const Color(0xFF34D399);
  return BrColors.gold;
}

class GrandeLogeLodgeLibraryScreen extends StatefulWidget {
  final LodgeReaderTarget target;
  final String type; // 'Architecture' | 'Instructions' | 'Rituels'
  const GrandeLogeLodgeLibraryScreen({
    super.key,
    required this.target,
    required this.type,
  });

  @override
  State<GrandeLogeLodgeLibraryScreen> createState() =>
      _GrandeLogeLodgeLibraryScreenState();
}

class _GrandeLogeLodgeLibraryScreenState
    extends State<GrandeLogeLodgeLibraryScreen> {
  LodgeConfig? _config;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _config = null;
      _error = null;
    });
    try {
      final config =
          await LodgeReaderService.instance.lodgeConfigOf(widget.target);
      if (mounted) setState(() => _config = config);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _open(String url) async {
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
    final folders = _config == null ? null : _foldersFor(_config!, widget.type);
    return Scaffold(
      appBar: AppBar(
        title: Text('${_typeNameFr(widget.type)} — ${widget.target.label}'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Text('Erreur : $_error',
                  style: const TextStyle(color: BrColors.error)),
            )
          : folders == null
              ? const Center(
                  child: CircularProgressIndicator(color: BrColors.gold),
                )
              : folders.isEmpty
                  ? const Center(
                      child: Text('Aucun dossier renseigné.',
                          style: TextStyle(color: BrColors.muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: folders.length,
                      itemBuilder: (context, i) {
                        final folder = folders[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BrMenuTile(
                            title: folder.label,
                            subtitle: 'Ouvrir sur Google Drive',
                            icon: Icons.folder_open_outlined,
                            color: _gradeColor(folder.grade),
                            onTap: () => _open(folder.url),
                          ),
                        );
                      },
                    ),
    );
  }
}
