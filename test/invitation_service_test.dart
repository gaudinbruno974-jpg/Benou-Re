import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/services/invitation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final members = [
    const Member(
      id: 'vm',
      firstName: 'Bruno',
      lastName: 'GAUDIN',
      function: 'Vénérable Maître',
    ),
    const Member(
      id: 'sec',
      firstName: 'Murielle',
      lastName: 'MARTIN-FANOU',
      function: 'Secrétaire',
      civilite: 'Sœur',
      phone: '0692000000',
    ),
  ];

  final session = Session.fromMap('s1', {
    'date': '2026-09-19T14:00:00',
    'dateReprise': '2026-09-19T14:00:00',
    'chrono': 12,
    'type': 'Ordinaire',
    'degree': 'Apprenti',
    'closingTime': '18:30',
    // Champ malgré son nom porteur de l'heure de clôture (voir
    // session_edit_screen.dart) : distincte de la vraie heure de reprise, ci
    // -dessus dans `dateReprise` — sert à vérifier qu'on ne les confond pas.
    'heureSuspension': '18:30',
    'hasAgape': true,
    'montantMedaille': 15,
    'heureAgape': '20:00',
    'typeRepas': 'Agape partage',
  });

  const url = 'https://benou-re-loge.web.app/#/reponse/abc-123';
  const ordreDuJour = ['Lecture de la correspondance'];

  test('le titre reprend le chrono et la date', () {
    expect(invitationTitle(session, 12), 'Tenue 12 du 19/09/2026');
  });

  test('les objets distinguent Convocation (membre) et Invitation (dignitaire)', () {
    final subjMember = memberConvocationSubject(session, 12);
    final subjDignitary = dignitaryInvitationSubject(session, 12);
    expect(subjMember, startsWith('Convocation à la Tenue n°12'));
    expect(subjDignitary, startsWith('Invitation à la Tenue n°12'));
    expect(subjMember, contains('Ordinaire'));
    expect(subjMember, contains('19/09/26'));
  });

  test(
    'le texte membre contient le paragraphe accueil des apprentis, le lien et le mandatement',
    () {
      final body = memberConvocationBody(session, ordreDuJour, members, url);
      expect(body, contains("FF∴ et SS∴ apprentis d'arriver à"));
      expect(body, contains('Salle Humide'));
      expect(body, contains('Tél : 0692000000'));
      expect(body, contains(url));
      expect(body, contains('Par mandatement du V∴M∴ Bru∴ GAU∴'));
      expect(body, contains('Le S∴ Sec∴ Mur∴ MAR∴-FAN∴'));
      expect(body, contains('vous informe de sa prochaine'));
    },
  );

  test(
    'le texte dignitaire omet le paragraphe réservé aux membres mais garde le mandatement',
    () {
      final body = dignitaryInvitationBody(
        session,
        ordreDuJour,
        members,
        url,
      );
      expect(body, isNot(contains('Salle Humide')));
      expect(body, isNot(contains("apprentis d'arriver")));
      expect(body, contains(url));
      expect(body, contains('Par mandatement du V∴M∴ Bru∴ GAU∴'));
      expect(body, contains('Le S∴ Sec∴ Mur∴ MAR∴-FAN∴'));
      expect(body, contains("a l'honneur de vous informer"));
    },
  );

  test('la ligne agapes reprend heure, type et montant de la médaille', () {
    final body = memberConvocationBody(session, const [], members, url);
    expect(
      body,
      contains(
        "Les travaux seront suivis d'agapes à 20:00 (Agape partage) "
        '(participation pour la médaille : 15 €).',
      ),
    );
  });

  test(
    'l\'heure de reprise vient de la date de la tenue, pas de heureSuspension '
    '(qui porte en réalité la clôture)',
    () {
      final body = memberConvocationBody(session, const [], members, url);
      expect(body, contains('de 14h00 à 18:30'));
      expect(body, isNot(contains('de 18:30 à 18:30')));
    },
  );

  test("l'ordre du jour est numéroté dans les deux textes", () {
    final body = dignitaryInvitationBody(
      session,
      ordreDuJour,
      members,
      url,
    );
    expect(body, contains('1. Lecture de la correspondance'));
  });
}
