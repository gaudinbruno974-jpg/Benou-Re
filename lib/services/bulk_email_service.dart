// Envoi groupé d'e-mails personnalisés — partagé par les Invitations
// internes (session_invitations_screen.dart) et le Registre des Tenues
// extérieures (external_sessions_screen.dart) : un e-mail réel par
// destinataire (même PDF joint à chacun, texte et lien de réponse propres à
// chacun), jamais un CCI unique ni un brouillon à valider un par un — voir
// DriveService.sendGmailWithAttachment.
import 'dart:typed_data';

import 'drive_service.dart';

/// Résultat d'un envoi groupé : un e-mail séparé et personnalisé par
/// destinataire.
class BulkSendResult {
  final int sent;
  final int skippedNoEmail;
  final int failed;
  const BulkSendResult({
    required this.sent,
    required this.skippedNoEmail,
    required this.failed,
  });

  String get summary {
    final parts = <String>['$sent e-mail(s) envoyé(s)'];
    if (skippedNoEmail > 0) {
      parts.add('$skippedNoEmail ignoré(s) (pas d\'e-mail)');
    }
    if (failed > 0) parts.add('$failed échec(s)');
    return '${parts.join(', ')}.';
  }
}

/// Envoie directement un e-mail par destinataire. Envoi réel, pas un
/// brouillon : le contenu est entièrement généré, une relecture
/// individuelle dans Gmail n'apporterait rien et obligerait à cliquer
/// « Envoyer » une fois par destinataire après coup.
Future<BulkSendResult> sendBulkGmails({
  Uint8List? pdfBytes,
  String? attachmentName,
  required List<({String email, String subject, String body})> recipients,
  required void Function(int done, int total) onProgress,
  String attachmentContentType = 'application/pdf',
}) async {
  var sent = 0, skipped = 0, failed = 0, done = 0;
  for (final r in recipients) {
    done++;
    onProgress(done, recipients.length);
    if (r.email.trim().isEmpty) {
      skipped++;
      continue;
    }
    try {
      await DriveService.instance.sendGmailWithAttachment(
        to: r.email.trim(),
        subject: r.subject,
        body: r.body,
        attachmentName: attachmentName,
        attachmentBytes: pdfBytes,
        attachmentContentType: attachmentContentType,
      );
      sent++;
    } catch (_) {
      failed++;
    }
  }
  return BulkSendResult(sent: sent, skippedNoEmail: skipped, failed: failed);
}
