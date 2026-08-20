// Génération des textes de convocation (membres) et d'invitation
// (dignitaires/Vénérables d'autres Loges) envoyés via un lien de réponse
// individuel (voir presence_link.dart) — chaque texte est personnalisé, le
// lien de réponse étant propre au destinataire : pas de texte partagé unique
// pour tout un groupe.

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../config/lodge_config.dart';
import '../models/civilite.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../utils/name_mask.dart';
import 'pdf_service.dart' show accueilApprentisHeure, plancheVmName;

String _dateLongue(Session session) {
  final dt = session.dateTime;
  return dt == null
      ? 'date à définir'
      : DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

String _dateCourte(Session session) {
  final dt = session.dateTime;
  return dt == null ? 'jj/mm/aa' : DateFormat('dd/MM/yy').format(dt);
}

String _degreOrdinal(String degre) => Session.degreeOrdinal(degre);

/// Libellé dénormalisé d'une tenue (« Tenue X du jj/mm/aaaa »), utilisé pour
/// l'affichage sur la page publique d'un lien de réponse (PresenceLink).
String invitationTitle(Session session, int chrono) {
  final dt = session.dateTime;
  final date = dt == null
      ? 'jj/mm/aaaa'
      : DateFormat('dd/MM/yyyy').format(dt);
  return 'Tenue $chrono du $date';
}

String _tenueLabel(Session session) =>
    'Tenue ${session.typeLabel} au ${_degreOrdinal(session.degreeLabel)} '
    'degré symbolique';

String _objet(String verbe, Session session, int chrono) =>
    '$verbe la Tenue n°$chrono (${session.typeLabel}) '
    '(${_degreOrdinal(session.degreeLabel)} degré) de la R∴L∴ '
    '${LodgeConfig.current.name} (${_dateCourte(session)})';

/// Objet du mail envoyé à un membre de la Loge.
String memberConvocationSubject(Session session, int chrono) =>
    _objet('Convocation à', session, chrono);

/// Objet du mail envoyé à un dignitaire ou un Vénérable d'une autre Loge.
String dignitaryInvitationSubject(Session session, int chrono) =>
    _objet('Invitation à', session, chrono);

/// Heure de reprise des travaux, lue sur la date/heure de la tenue — pas sur
/// `heureSuspension`, qui malgré son nom porte en réalité l'heure de
/// clôture (même valeur que `closingTime`, voir session_edit_screen.dart).
String _heureDebut(Session session) {
  final dt = session.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) {
    return 'une heure à préciser';
  }
  return '${dt.hour.toString().padLeft(2, '0')}h'
      '${dt.minute.toString().padLeft(2, '0')}';
}

/// Heure et type d'agapes (« à 20h00 (Agape partage) »), pour compléter la
/// ligne de participation sans dupliquer cette lecture ailleurs.
String _agapeDetails(Session session) {
  final heure = (session.heureAgape ?? session.agapeTime).trim();
  final type = (session.typeRepas ?? session.agapeType).trim();
  final parts = [if (heure.isNotEmpty) 'à $heure', if (type.isNotEmpty) '($type)'];
  return parts.isEmpty ? '' : ' ${parts.join(' ')}';
}

String _lieu(Session session) {
  final l = (session.lieuReunionExtra ?? session.location).trim();
  return l.isEmpty ? LodgeConfig.current.defaultMeetingPlace : l;
}

/// Corps commun aux deux textes : annonce de la tenue, lieu/horaires, ordre
/// du jour, ligne Agapes, et la phrase de clôture avant les paragraphes
/// spécifiques à chaque destinataire.
List<String> _commonLines(
  Session session,
  List<String> ordreDuJour, {
  required String informerVerbe,
}) {
  final lines = <String>[
    'Très Chers Frères, Très Chères Sœurs,',
    '',
    'La R∴L∴ ${LodgeConfig.current.name} $informerVerbe de sa prochaine '
        '${_tenueLabel(session)} qui se tiendra le ${_dateLongue(session)}.',
    '',
    'Nous avons le plaisir de vous convier fraternellement à participer à '
        'nos travaux, qui se dérouleront de ${_heureDebut(session)} à '
        '${session.closingTime} au ${_lieu(session)}.',
  ];
  if (ordreDuJour.isNotEmpty) {
    lines.add('');
    lines.add('Ordre du jour :');
    for (var i = 0; i < ordreDuJour.length; i++) {
      lines.add('${i + 1}. ${ordreDuJour[i]}');
    }
  }
  if (session.suitAgapes) {
    final prix = (session.montantMedaille ?? 0) > 0
        ? session.montantMedaille!
        : session.agapePrice;
    final medaille = prix > 0 ? ' (participation pour la médaille : $prix €)' : '';
    lines.add('');
    lines.add(
      "Les travaux seront suivis d'agapes${_agapeDetails(session)}$medaille.",
    );
  }
  lines.add('');
  lines.add(
    'Votre présence et votre participation contribueront à la richesse de '
    'nos échanges.',
  );
  return lines;
}

/// Paragraphe réservé aux membres de la Loge (accueil des apprentis, rappel
/// des agapes en Salle Humide, téléphone du Secrétariat).
List<String> _memberOnlyLines(Session session, Member? secretary) {
  final secretaryPhone = secretary?.phone.trim() ?? '';
  final telSuffix = secretaryPhone.isEmpty ? '' : ' Tél : $secretaryPhone';
  return [
    '',
    "Je remercie tous les FF∴ et SS∴ apprentis d'arriver à "
        '${accueilApprentisHeure(session)} pour aider à la mise en place du '
        'Temple sous la houlette du Maître Second Surveillant et du Maître '
        'Expert.',
    '',
    "Les Travaux seront suivis d'Agapes fraternelles en Salle Humide. "
        "Merci aux SS∴ et FF∴ Invités de s'annoncer afin d'ajuster au mieux "
        'les Agapes.$telSuffix',
  ];
}

List<String> _linkLines(String responseUrl) => [
  '',
  'Le lien ci-dessous vous permet de nous répondre directement et '
      "d'anticiper pour l'organisation de la tenue et des agapes :",
  '',
  "Vous pouvez modifier votre réponse jusqu'à minuit la veille de la tenue.",
  '',
  responseUrl,
];

/// Signature commune : mandatement du V∴M∴ et du Secrétaire (noms masqués,
/// même convention que les documents PDF — voir maskPersonName).
List<String> _signOffLines(
  Session session,
  List<Member> members,
  Member? secretary, {
  String lodgeVmName = '',
}) {
  final vmName = maskPersonName(
    plancheVmName(session, members, lodgeVmName: lodgeVmName),
  );
  final secretaryName = secretary != null
      ? maskPersonName(secretary.fullName)
      : 'Secrétaire';
  final secretaryCivilite = civiliteAbbrev(secretary?.civilite ?? '');
  return [
    '',
    'Par mandatement du V∴M∴ $vmName',
    'Le $secretaryCivilite Sec∴ $secretaryName',
    'Fraternellement,',
    'Le Secrétariat',
  ];
}

Member? _findSecretary(List<Member> members) =>
    members.where((m) => foldLabel(m.function).contains('secretaire')).firstOrNull;

/// Corps du mail/message envoyé à un membre de la Loge, avec son lien de
/// réponse personnel inséré.
String memberConvocationBody(
  Session session,
  List<String> ordreDuJour,
  List<Member> members,
  String responseUrl, {
  String lodgeVmName = '',
}) {
  final secretary = _findSecretary(members);
  final lines = [
    ..._commonLines(session, ordreDuJour, informerVerbe: 'vous informe'),
    ..._memberOnlyLines(session, secretary),
    ..._linkLines(responseUrl),
    ..._signOffLines(session, members, secretary, lodgeVmName: lodgeVmName),
  ];
  return lines.join('\n');
}

/// Corps du mail/message envoyé à un dignitaire ou un Vénérable d'une autre
/// Loge, avec son lien de réponse personnel inséré.
String dignitaryInvitationBody(
  Session session,
  List<String> ordreDuJour,
  List<Member> members,
  String responseUrl, {
  String lodgeVmName = '',
}) {
  final secretary = _findSecretary(members);
  final lines = [
    ..._commonLines(
      session,
      ordreDuJour,
      informerVerbe: "a l'honneur de vous informer",
    ),
    ..._linkLines(responseUrl),
    ..._signOffLines(session, members, secretary, lodgeVmName: lodgeVmName),
  ];
  return lines.join('\n');
}
