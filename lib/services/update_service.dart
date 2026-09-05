// Vérification d'une mise à jour Android disponible, l'application étant
// distribuée hors Play Store (donc sans mécanisme de mise à jour
// automatique) : au premier affichage du Parvis, on compare le numéro de
// build installé à celui publié dans `config/settings` (voir
// LodgeConfig.latestAndroidVersionCode), lui-même mis à jour à la main à
// chaque nouvelle APK déposée sur Drive — voir parvis_screen.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/lodge_config.dart';

class UpdateService {
  /// `null` si aucune mise à jour n'est disponible (déjà à jour, plateforme
  /// autre qu'Android, ou réglage absent/incomplet côté Loge).
  Future<({String versionName, String downloadUrl})?> verifier() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final lodge = LodgeConfig.current;
    if (lodge.latestAndroidVersionCode <= 0 ||
        lodge.androidApkDownloadUrl.isEmpty) {
      return null;
    }

    final infos = await PackageInfo.fromPlatform();
    final versionCodeInstalle = int.tryParse(infos.buildNumber) ?? 0;
    if (lodge.latestAndroidVersionCode <= versionCodeInstalle) {
      return null;
    }

    return (
      versionName: lodge.latestAndroidVersionName,
      downloadUrl: lodge.androidApkDownloadUrl,
    );
  }

  /// Vérifie et, si une nouvelle version existe, propose son
  /// téléchargement (« Oui » ouvre le lien dans le navigateur, « Non »
  /// referme la popup) — silencieux si déjà à jour.
  Future<void> verifierEtProposer(BuildContext context) async {
    ({String versionName, String downloadUrl})? maj;
    try {
      maj = await verifier();
    } catch (_) {
      return;
    }
    if (maj == null || !context.mounted) return;
    final versionName = maj.versionName;
    final downloadUrl = maj.downloadUrl;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mise à jour disponible'),
        content: Text(
          'Une nouvelle version${versionName.isEmpty ? '' : ' (v$versionName)'} '
          'de l\'application est disponible.\n\nMettre à jour maintenant ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final uri = Uri.parse(downloadUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }
}
