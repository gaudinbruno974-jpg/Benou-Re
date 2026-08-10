// Génération des textes d'invitation d'une Tenue planifiée.
//
// L'API WhatsApp Business ne permet ni de créer un sondage ni d'écrire dans un
// groupe : l'app se limite donc à produire le contenu, que l'utilisateur colle
// dans le groupe de son choix (deep link wa.me) ou envoie par e-mail (mailto).

import 'package:intl/intl.dart';

import '../models/member.dart';
import '../models/session.dart';

/// Compteurs de présence d'une Tenue, par degré, plus les agapes.
class InvitationCounts {
  final int maitres;
  final int compagnons;
  final int apprentis;
  final int agapes;

  const InvitationCounts({
    this.maitres = 0,
    this.compagnons = 0,
    this.apprentis = 0,
    this.agapes = 0,
  });

  int get total => maitres + compagnons + apprentis;
}

String _dateSlash(Session session) {
  final dt = session.dateTime;
  return dt == null ? 'jj/mm/aaaa' : DateFormat('dd/MM/yyyy').format(dt);
}

String _dateLongue(Session session) {
  final dt = session.dateTime;
  return dt == null
      ? 'date à définir'
      : DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

String _degreOrdinal(String degre) => Session.degreeOrdinal(degre);

/// Titre commun aux messages : « Tenue X du jj/mm/aaaa ».
String invitationTitle(Session session, int chrono) =>
    'Tenue $chrono du ${_dateSlash(session)}';

/// Compte les membres présents par degré et le nombre d'agapes.
InvitationCounts invitationCounts(Session session, List<Member> members) {
  var maitres = 0;
  var compagnons = 0;
  var apprentis = 0;
  for (final m in members.where((m) => session.presentIds.contains(m.id))) {
    switch (normalizeGrade(m.grade)) {
      case kMaitre:
        maitres++;
      case kCompagnon:
        compagnons++;
      default:
        apprentis++;
    }
  }
  return InvitationCounts(
    maitres: maitres,
    compagnons: compagnons,
    apprentis: apprentis,
    agapes: session.agapeIds.length,
  );
}

/// Corps commun aux invitations (convocation, ordre du jour, agapes).
String invitationBody(Session session, int chrono, List<String> ordreDuJour) {
  final lines = <String>[
    invitationTitle(session, chrono),
    '',
    'Très Chers Frères, Très Chères Sœurs,',
    'Vous êtes invités en Tenue ${session.typeLabel} au '
        '${_degreOrdinal(session.degreeLabel)} degré symbolique, '
        'le ${_dateLongue(session)}.',
  ];
  final lieu = (session.lieuReunionExtra ?? session.location).trim();
  if (lieu.isNotEmpty) lines.add('Lieu : $lieu.');
  final ouverture = (session.heureSuspension ?? '').trim();
  if (ouverture.isNotEmpty) lines.add('Ouverture des travaux : $ouverture.');
  if (ordreDuJour.isNotEmpty) {
    lines.add('');
    lines.add('Ordre du jour :');
    for (var i = 0; i < ordreDuJour.length; i++) {
      lines.add('${i + 1}. ${ordreDuJour[i]}');
    }
  }
  if (session.suitAgapes) {
    final heure = (session.heureAgape ?? session.agapeTime).trim();
    final type = (session.typeRepas ?? session.agapeType).trim();
    final prix = session.agapePrice;
    final details = <String>[
      if (heure.isNotEmpty) heure,
      if (type.isNotEmpty) type,
      if (prix > 0) '$prix €',
    ].join(' — ');
    lines.add('');
    lines.add('Agapes : ${details.isEmpty ? 'à confirmer' : details}.');
  }
  return lines.join('\n');
}

/// Message destiné au groupe WhatsApp de la Loge : le corps de l'invitation
/// suivi des 4 questions à reporter dans le sondage WhatsApp.
String lodgeInvitationText(
  Session session,
  int chrono,
  List<String> ordreDuJour,
) {
  return '${invitationBody(session, chrono, ordreDuJour)}\n\n'
      'Sondage :\n'
      'Présent en tenue : OUI\n'
      'Présent en tenue : NON\n'
      'Présent en agapes : OUI\n'
      'Présent en agapes : NON';
}

/// Message destiné au groupe WhatsApp de l'Obédience : les compteurs de
/// présence de notre Loge, à jour au moment de l'envoi.
String obedienceInvitationText(
  Session session,
  List<Member> members,
  int chrono,
) {
  final c = invitationCounts(session, members);
  return '${invitationTitle(session, chrono)}\n\n'
      'Présent tenue\n'
      'Maîtres - ${c.maitres}\n'
      'Compagnons - ${c.compagnons}\n'
      'Apprentis - ${c.apprentis}\n\n'
      'Présent agapes\n'
      'Nombre - ${c.agapes}';
}

/// Corps de l'invitation par e-mail (mêmes informations, sans le sondage).
String emailInvitationText(
  Session session,
  int chrono,
  List<String> ordreDuJour,
) {
  return '${invitationBody(session, chrono, ordreDuJour)}\n\n'
      'Merci de confirmer votre présence en tenue et aux agapes en réponse à '
      'ce message.';
}

/// Deep link WhatsApp avec le texte prérempli (le groupe est choisi dans
/// WhatsApp : l'API ne permet pas de cibler un groupe).
String whatsappShareUrl(String text) =>
    'https://wa.me/?text=${Uri.encodeComponent(text)}';

/// Lien mailto préremplissant destinataires, objet et corps.
String mailtoUrl({
  required List<String> recipients,
  required String subject,
  required String body,
}) {
  final query = <String>[
    'subject=${Uri.encodeComponent(subject)}',
    'body=${Uri.encodeComponent(body)}',
  ].join('&');
  return 'mailto:${recipients.map(Uri.encodeComponent).join(',')}?$query';
}
