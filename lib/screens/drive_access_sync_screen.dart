// Synchronisation des accès Drive par fonction — réservé au V∴M∴ (voir
// parvis_screen.dart). Écran volontairement simple : un bouton, un
// résumé de ce qui a changé, puis une photo des accès réels sur Drive.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/drive_access_sync_service.dart';
import '../services/drive_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

/// « Éditeur », « Propriétaire »… plutôt que les rôles techniques Drive.
const Map<String, String> _roleLabels = {
  'owner': 'Propriétaire',
  'writer': 'Éditeur',
  'commenter': 'Commentateur',
  'reader': 'Lecteur',
};

class DriveAccessSyncScreen extends StatefulWidget {
  const DriveAccessSyncScreen({super.key});

  @override
  State<DriveAccessSyncScreen> createState() => _DriveAccessSyncScreenState();
}

class _DriveAccessSyncScreenState extends State<DriveAccessSyncScreen> {
  final _service = DriveAccessSyncService();
  bool _running = false;
  bool _exporting = false;
  DriveAccessSyncResult? _result;
  String? _error;
  List<FolderAccessSummary>? _access;
  String? _accessError;

  Future<void> _run() async {
    final members = context.read<AppState>().members;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _access = null;
      _accessError = null;
    });
    // Authentifie une seule fois, AVANT la boucle sur les dossiers (Bureau +
    // Bibliothèque, une vingtaine désormais). Chaque appel Drive redemande
    // sinon sa propre autorisation dès que le jeton n'est pas en cache : si
    // cette toute première tentative échoue (fenêtre bloquée par le
    // navigateur), chaque dossier retente alors la sienne, ouvrant des
    // dizaines de fenêtres de connexion Google au lieu d'une seule.
    try {
      await DriveService.instance.ensureDriveAuthorization();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _running = false;
        });
      }
      return;
    }
    try {
      final result = await _service.sync(members);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    try {
      final access = await _service.currentAccess();
      if (mounted) setState(() => _access = access);
    } catch (e) {
      if (mounted) setState(() => _accessError = '$e');
    }
    if (mounted) setState(() => _running = false);
  }

  /// Archive un classeur des accès Drive actuels dans « 03 Dossier Membres »
  /// — même principe que l'archivage du Répertoire (un seul fichier à la
  /// fois, remplacé à chaque export), voir DriveService.archiveDirectoryDocument.
  Future<void> _exportReport() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final access = _access ?? await _service.currentAccess();
      final bytes = buildDriveAccessReportWorkbook(access);
      final loge = LodgeConfig.current.name;
      final driveDate = DateFormat('dd MM yy').format(DateTime.now());
      await DriveService.instance.archiveDirectoryDocument(
        namePrefix: 'Acces Drive $loge',
        fileName: 'Acces Drive $loge $driveDate.xlsx',
        bytes: Uint8List.fromList(bytes),
      );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Rapport des accès archivé sur Drive.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Erreur export : $e')));
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accès Drive')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const BrSectionTitle('SYNCHRONISATION', icon: Icons.sync),
          const SizedBox(height: 14),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Accorde l'accès aux dossiers Drive de la Loge au "
                  'V∴M∴, au Secrétaire et au Trésorier actuels, ainsi '
                  "qu'à chaque membre pour la Bibliothèque selon son "
                  'grade, et retire les accès devenus obsolètes. Ne '
                  "touche jamais un partage ajouté manuellement pour une "
                  'autre raison.',
                  style: TextStyle(color: BrColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: BrColors.text),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Synchroniser les accès Drive'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : _exportReport,
                  icon: _exporting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.grid_on_outlined),
                  label: const Text('Exporter les accès (xlsx)'),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            BrCard(
              accent: BrColors.error,
              child: Text('Erreur : $_error',
                  style: const TextStyle(color: BrColors.text)),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            const BrSectionTitle('RÉSULTAT', icon: Icons.fact_check_outlined),
            const SizedBox(height: 14),
            if (_result!.isEmpty)
              const BrCard(
                child: Text('Aucun changement : les accès étaient déjà à jour.',
                    style: TextStyle(color: BrColors.muted)),
              )
            else ...[
              if (_result!.granted.isNotEmpty)
                _resultCard('Accès accordés', _result!.granted,
                    const Color(0xFF34D399)),
              if (_result!.revoked.isNotEmpty)
                _resultCard('Accès retirés', _result!.revoked, BrColors.gold),
              if (_result!.driftCorrected.isNotEmpty)
                _resultCard(
                    'Dérive corrigée (accès périmé détecté sur Drive)',
                    _result!.driftCorrected,
                    BrColors.violet),
              if (_result!.roleFixed.isNotEmpty)
                _resultCard('Rôle corrigé', _result!.roleFixed, BrColors.teal),
              if (_result!.failed.isNotEmpty)
                _resultCard('Échecs', _result!.failed, BrColors.error),
            ],
          ],
          if (_accessError != null) ...[
            const SizedBox(height: 20),
            BrCard(
              accent: BrColors.error,
              child: Text('Lecture des accès existants : $_accessError',
                  style: const TextStyle(color: BrColors.text)),
            ),
          ],
          if (_access != null) ...[
            const SizedBox(height: 24),
            const BrSectionTitle('ACCÈS EXISTANTS',
                icon: Icons.folder_shared_outlined),
            const SizedBox(height: 14),
            for (final folder in _access!) _accessCard(folder),
          ],
        ],
      ),
    );
  }

  Widget _accessCard(FolderAccessSummary folder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrCard(
        accent: BrColors.violet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(folder.folderName,
                style: const TextStyle(
                    color: BrColors.violet, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (folder.entries.isEmpty)
              const Text('Aucun accès particulier.',
                  style: TextStyle(color: BrColors.muted, fontSize: 13))
            else
              for (final e in folder.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${e.email} — ${_roleLabels[e.role] ?? e.role}',
                    style:
                        const TextStyle(color: BrColors.text, fontSize: 13),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(String title, List<String> lines, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrCard(
        accent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line,
                    style: const TextStyle(color: BrColors.text, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
