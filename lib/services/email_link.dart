// Construit un lien d'envoi d'e-mail, à ouvrir via openExternalUrl.
// `mailto:` ne fonctionne que si le navigateur a un client mail natif
// associé (souvent absent chez les utilisateurs Gmail/webmail sur
// ordinateur) : sur le web on ouvre donc directement la fenêtre de
// composition Gmail, qui n'a pas ce prérequis. Sur mobile, `mailto:`
// déclenche normalement le choix de l'app mail installée.
import 'package:flutter/foundation.dart' show kIsWeb;

String emailComposeUrl({
  required String to,
  required String subject,
  required String body,
}) {
  if (kIsWeb) {
    return 'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(to)}'
        '&su=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';
  }
  return 'mailto:$to'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}
