// Vérification de l'accès Drive IAH-MES — pas de synchronisation
// automatique par fonction/degré (confirmé par l'utilisateur, à la
// différence des loges bleues) : seuls deux comptes doivent avoir accès à
// tous les dossiers, gaudin.bruno974@gmail.com et iahmes.sstr@gmail.com.
// Cet écran se contente de vérifier et, si besoin, de corriger.
import 'package:flutter/material.dart';

import '../services/drive_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

const List<String> kIahMesDriveFolders = [
  '01 Association',
  '02 Banque',
  '03 Dossier Membres',
  '04 Location temple assurance',
  '05 Factures',
  '06 Invitations Externes recues',
  '07 Planches',
  '08 Rituel',
  '09 Tenues et PV',
  '10 Capitations',
  '11 Enquêtes',
  '12 instruction',
  '13 Ticket Applications',
  "14 Rapports d'activité",
];

const List<String> kIahMesDriveRequiredEmails = [
  'gaudin.bruno974@gmail.com',
  'iahmes.sstr@gmail.com',
];

class _FolderAccessState {
  final String name;
  final String folderId;
  final Map<String, bool> hasAccess;
  _FolderAccessState({
    required this.name,
    required this.folderId,
    required this.hasAccess,
  });
}

class GrandeLogeHgDriveAccessScreen extends StatefulWidget {
  const GrandeLogeHgDriveAccessScreen({super.key});

  @override
  State<GrandeLogeHgDriveAccessScreen> createState() =>
      _GrandeLogeHgDriveAccessScreenState();
}

class _GrandeLogeHgDriveAccessScreenState
    extends State<GrandeLogeHgDriveAccessScreen> {
  bool _loading = true;
  String? _error;
  List<_FolderAccessState> _folders = [];
  final Set<String> _fixing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await DriveService.instance.ensureFolderTree(const [
        'IAH-MES',
      ], kIahMesDriveFolders);
      final folders = <_FolderAccessState>[];
      for (final name in kIahMesDriveFolders) {
        final folderId = ids[name];
        if (folderId == null) continue;
        final entries = await DriveService.instance.listFolderAccess(
          folderId: folderId,
        );
        final emails = entries.map((e) => e.email.toLowerCase()).toSet();
        folders.add(
          _FolderAccessState(
            name: name,
            folderId: folderId,
            hasAccess: {
              for (final email in kIahMesDriveRequiredEmails)
                email: emails.contains(email.toLowerCase()),
            },
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _grant(_FolderAccessState folder, String email) async {
    final key = '${folder.folderId}|$email';
    setState(() => _fixing.add(key));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DriveService.instance.grantFolderAccess(
        folderId: folder.folderId,
        email: email,
        role: 'writer',
      );
      if (!mounted) return;
      setState(() => folder.hasAccess[email] = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _fixing.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accès Drive'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: BrColors.gold))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur : $_error',
                  style: const TextStyle(color: BrColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Vérifie que ces deux comptes ont accès à chaque '
                    'dossier IAH-MES. Aucun autre accès automatique '
                    "n'est géré ici.",
                    style: TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ),
                for (final folder in _folders)
                  BrCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          style: const TextStyle(
                            color: BrColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final email in kIahMesDriveRequiredEmails)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  folder.hasAccess[email] == true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 16,
                                  color: folder.hasAccess[email] == true
                                      ? BrColors.menuVisiteurs
                                      : BrColors.menuTresorerie,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: const TextStyle(
                                      color: BrColors.text,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                if (folder.hasAccess[email] != true)
                                  TextButton(
                                    onPressed:
                                        _fixing.contains(
                                          '${folder.folderId}|$email',
                                        )
                                        ? null
                                        : () => _grant(folder, email),
                                    child: Text(
                                      _fixing.contains(
                                            '${folder.folderId}|$email',
                                          )
                                          ? '...'
                                          : 'Corriger',
                                      style: const TextStyle(
                                        color: BrColors.teal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
