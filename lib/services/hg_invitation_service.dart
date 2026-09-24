// Génération des textes de convocation (membres) et d'invitation
// (dignitaires) pour une tenue de Hauts Grades (IAH-MES, MAA-Kherou) —
// même principe qu'invitation_service.dart (loges bleues), adapté : pas de
// LodgeConfig (le libellé institutionnel vient de HgBody, voir
// hg_pdf_service.dart), pas de paragraphe « accueil des apprentis » (loges
// bleues uniquement, sans équivalent ici), signataire toujours le Trois
// Fois Puissant Maître (session.vmName), pas de recherche d'un Secrétaire
// par fonction — les corps de Hauts Grades n'ont pas cette taxonomie de
// postes.
import 'package:intl/intl.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../utils/name_mask.dart';
import 'hg_pdf_service.dart' show hgDegreeOrdinalPhrase, hgInstitutionHeader;
import 'invitation_service.dart' show presenceGreeting;

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

/// Libellé dénormalisé d'une tenue (« Tenue X du jj/mm/aaaa »), utilisé pour
/// l'affichage sur la page publique d'un lien de réponse (HgPresenceLink).
String hgInvitationTitle(Session session, int chrono) {
  final dt = session.dateTime;
  final date = dt == null ? 'jj/mm/aaaa' : DateFormat('dd/MM/yyyy').format(dt);
  return 'Tenue $chrono du $date';
}

String _objet(String verbe, HgBody body, Session session, int chrono) =>
    '$verbe la Tenue n°$chrono de ${hgInstitutionHeader(body)} '
    '(${_dateCourte(session)})';

/// Objet du mail envoyé à un membre du corps.
String hgMemberConvocationSubject(HgBody body, Session session, int chrono) =>
    _objet('Convocation à', body, session, chrono);

/// Objet du mail envoyé à un dignitaire invité.
String hgDignitaryInvitationSubject(HgBody body, Session session, int chrono) =>
    _objet('Invitation à', body, session, chrono);

int _degreeOf(Session session) =>
    int.tryParse(session.degreTravail ?? session.degree) ?? 4;

String _heureDebut(Session session) {
  final dt = session.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) {
    return 'une heure à préciser';
  }
  return '${dt.hour.toString().padLeft(2, '0')}h'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _agapeDetails(Session session) {
  final heure = (session.heureAgape ?? session.agapeTime).trim();
  final type = (session.typeRepas ?? session.agapeType).trim();
  final parts = [
    if (heure.isNotEmpty) 'à $heure',
    if (type.isNotEmpty) '($type)',
  ];
  return parts.isEmpty ? '' : ' ${parts.join(' ')}';
}

String _lieu(Session session) {
  final l = (session.lieuReunionExtra ?? session.location).trim();
  return l.isEmpty ? 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre' : l;
}

/// Corps commun aux deux textes : annonce de la tenue, lieu/horaires, ordre
/// du jour, ligne Agapes, et la phrase de clôture avant les paragraphes
/// spécifiques à chaque destinataire.
List<String> _commonLines(
  HgBody body,
  Session session,
  List<String> ordreDuJour, {
  required String informerVerbe,
  required String greeting,
}) {
  final degree = _degreeOf(session);
  final lines = <String>[
    greeting,
    '',
    '${hgInstitutionHeader(body)} $informerVerbe de sa prochaine tenue '
        '(${hgDegreeOrdinalPhrase(body, degree)}) qui se tiendra le '
        '${_dateLongue(session)}.',
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
    final prix = session.montantMedaille ?? 0;
    final medaille = prix > 0
        ? ' (participation pour la médaille : $prix €)'
        : '';
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

List<String> _linkLines(String responseUrl) => [
  '',
  'Le lien ci-dessous vous permet de nous répondre directement et '
      "d'anticiper pour l'organisation de la tenue et des agapes :",
  '',
  "Vous pouvez modifier votre réponse jusqu'à minuit la veille de la tenue.",
  '',
  responseUrl,
];

/// Signature : le Trois Fois Puissant Maître (nom masqué, même convention
/// que les documents PDF — voir maskPersonName), pas de mandatement de
/// Secrétaire (pas de taxonomie de postes équivalente en Hauts Grades).
List<String> _signOffLines(Session session) {
  final signerName = (session.vmName ?? '').trim().isEmpty
      ? 'Trois Fois Puissant Maître'
      : maskPersonName(session.vmName!.trim());
  return ['', 'Fraternellement,', 'Le Trois Fois Puissant Maître $signerName'];
}

/// Corps du mail/message envoyé à un membre du corps, avec son lien de
/// réponse personnel inséré.
String hgMemberConvocationBody(
  HgBody body,
  Session session,
  List<String> ordreDuJour,
  String responseUrl, {
  Member? recipient,
}) {
  final greeting = presenceGreeting(
    civilite: recipient?.civilite ?? '',
    firstName: recipient?.firstName ?? '',
  );
  final lines = [
    ..._commonLines(
      body,
      session,
      ordreDuJour,
      informerVerbe: 'vous informe',
      greeting: greeting,
    ),
    ..._linkLines(responseUrl),
    ..._signOffLines(session),
  ];
  return lines.join('\n');
}

/// Corps du mail/message envoyé à un dignitaire invité, avec son lien de
/// réponse personnel inséré.
String hgDignitaryInvitationBody(
  HgBody body,
  Session session,
  List<String> ordreDuJour,
  String responseUrl, {
  Dignitary? recipient,
}) {
  final greeting = presenceGreeting(
    civilite: recipient?.civilite ?? '',
    firstName: recipient?.firstName ?? '',
  );
  final lines = [
    ..._commonLines(
      body,
      session,
      ordreDuJour,
      informerVerbe: "a l'honneur de vous informer",
      greeting: greeting,
    ),
    ..._linkLines(responseUrl),
    ..._signOffLines(session),
  ];
  return lines.join('\n');
}
