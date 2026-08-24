// Génération du texte de diffusion d'une Tenue extérieure reçue (Registre
// des Tenues extérieures, voir external_session.dart) aux membres de la
// Loge courante — même principe que les Convocations internes (voir
// invitation_service.dart : salutation personnalisée, lien de réponse
// individuel), mais sans volet Agapes (ce n'est pas une tenue organisée par
// la Loge courante) et signé par le seul contact choisi à l'enregistrement
// (Secrétaire ou Vénérable Maître), pas le duo V∴M∴/Secrétaire des
// convocations internes.
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../models/civilite.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../utils/name_mask.dart';
import 'invitation_service.dart' show presenceGreeting;

String _dateLongue(ExternalSession s) {
  final dt = s.dateTime;
  return dt == null
      ? 'date à définir'
      : DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

String _dateCourte(ExternalSession s) {
  final dt = s.dateTime;
  return dt == null ? 'jj/mm/aa' : DateFormat('dd/MM/yy').format(dt);
}

/// Heure de la tenue extérieure, si connue.
String _heure(ExternalSession s) {
  final dt = s.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) return '';
  return '${dt.hour.toString().padLeft(2, '0')}h'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String externalInvitationSubject(ExternalSession s) =>
    'Invitation reçue de la R∴L∴ ${s.organizingLodge} (${_dateCourte(s)})';

Member? _findSecretary(List<Member> members) => members
    .where((m) => foldLabel(m.function).contains('secretaire'))
    .firstOrNull;

Member? _findVenerable(List<Member> members) => members
    .where((m) => foldLabel(m.function).contains('venerable'))
    .firstOrNull;

/// Civilité abrégée + nom (masqué) du contact choisi à l'enregistrement —
/// coordonnées reprises du réglage de la Loge (nom du V∴M∴) ou de la fiche
/// du Secrétaire, comme pour les autres documents générés (voir
/// plancheVmName, treasury_document_service.dart).
({String title, String name}) _contactInfo(
  ExternalSession s,
  List<Member> members,
  String lodgeVmName,
) {
  if (s.contactPerson == kExternalContactVenerable) {
    final vm = _findVenerable(members);
    final name = lodgeVmName.trim().isNotEmpty
        ? lodgeVmName.trim()
        : (vm != null ? vm.fullName : 'Vénérable Maître');
    return (title: 'V∴M∴', name: maskPersonName(name));
  }
  final secretary = _findSecretary(members);
  final name =
      secretary != null ? maskPersonName(secretary.fullName) : 'Secrétaire';
  final civ = civiliteAbbrev(secretary?.civilite ?? '');
  return (title: '$civ Sec∴', name: name);
}

/// Corps du mail envoyé à un membre de la Loge pour relayer une invitation
/// reçue, avec son lien de réponse personnel inséré. Même salutation
/// nominative que les Convocations internes.
String externalInvitationBody(
  ExternalSession s,
  List<Member> members,
  String responseUrl, {
  String lodgeVmName = '',
  Member? recipient,
}) {
  final greeting = presenceGreeting(
    civilite: recipient?.civilite ?? '',
    firstName: recipient?.firstName ?? '',
  );
  final contact = _contactInfo(s, members, lodgeVmName);
  final heure = _heure(s);
  final lieu = s.location.trim();
  final lines = <String>[
    greeting,
    '',
    'La R∴L∴ ${s.organizingLodge}'
        '${s.obedience.trim().isEmpty ? '' : ' (${s.obedience.trim()})'} '
        'nous invite à sa ${s.eventTypeLabel}, qui se tiendra le '
        '${_dateLongue(s)}'
        '${heure.isEmpty ? '' : ' à $heure'}'
        '${lieu.isEmpty ? '' : ', $lieu'}.',
    '',
    'Merci de nous indiquer si vous comptez vous y rendre, afin d\'en '
        'informer nos hôtes :',
    '',
    "Vous pouvez modifier votre réponse jusqu'à la veille de la tenue.",
    '',
    responseUrl,
  ];
  if (s.notes.trim().isNotEmpty) {
    lines.addAll(['', s.notes.trim()]);
  }
  lines.addAll([
    '',
    'Pour toute question : ${contact.title} ${contact.name}',
    '',
    'Fraternellement,',
    'Le Secrétariat',
  ]);
  return lines.join('\n');
}
