// Synchronisation des accès Drive par fonction — réservé au V∴M∴ (voir
// parvis_screen.dart). Écran volontairement simple : un bouton, un
// résumé de ce qui a changé.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/drive_access_sync_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class DriveAccessSyncScreen extends StatefulWidget {
  const DriveAccessSyncScreen({super.key});

  @override
  State<DriveAccessSyncScreen> createState() => _DriveAccessSyncScreenState();
}

class _DriveAccessSyncScreenState extends State<DriveAccessSyncScreen> {
  bool _running = false;
  DriveAccessSyncResult? _result;
  String? _error;

  Future<void> _run() async {
    final members = context.read<AppState>().members;
    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await DriveAccessSyncService().sync(members);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
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
                  'V∴M∴, au Secrétaire et au Trésorier actuels, et retire '
                  "l'accès de ceux qui ont quitté ces fonctions. Ne touche "
                  "jamais un partage ajouté manuellement pour une autre "
                  'raison.',
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
              if (_result!.failed.isNotEmpty)
                _resultCard('Échecs', _result!.failed, BrColors.error),
            ],
          ],
        ],
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
