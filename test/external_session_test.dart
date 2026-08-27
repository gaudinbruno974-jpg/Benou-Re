// Registre des Tenues extérieures : bascule vers l'historique, filtrage des
// destinataires par degré concerné, et mise à jour de la participation à
// partir des réponses reçues par lien.
import 'package:benou_re/models/external_session.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/presence_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPast', () {
    test('faux tant que la date n\'est pas dépassée', () {
      final s = ExternalSession(
        id: 'e1',
        date: DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      );
      expect(s.isPast, isFalse);
    });

    test('vrai une fois la date dépassée', () {
      final s = ExternalSession(
        id: 'e2',
        date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      );
      expect(s.isPast, isTrue);
    });

    test('faux quand la date est absente (jamais renseignée)', () {
      const s = ExternalSession(id: 'e3');
      expect(s.isPast, isFalse);
    });
  });

  group('eligibleExternalRecipients', () {
    const apprenti = Member(id: 'm1', firstName: 'A', lastName: 'A', grade: kApprenti);
    const compagnon = Member(id: 'm2', firstName: 'B', lastName: 'B', grade: kCompagnon);
    const maitre = Member(id: 'm3', firstName: 'C', lastName: 'C', grade: kMaitre);
    final members = [apprenti, compagnon, maitre];

    test('« Tous » cible l\'ensemble des membres', () {
      final result = eligibleExternalRecipients(kExternalDegreeAll, members);
      expect(result, members);
    });

    test('un degré Apprenti cible tout le monde (grade supérieur inclus)', () {
      final result = eligibleExternalRecipients(kApprenti, members);
      expect(result, members);
    });

    test('un degré Maître ne cible que les Maîtres', () {
      final result = eligibleExternalRecipients(kMaitre, members);
      expect(result, [maitre]);
    });

    test('un degré Compagnon exclut les Apprentis mais garde les Maîtres', () {
      final result = eligibleExternalRecipients(kCompagnon, members);
      expect(result, [compagnon, maitre]);
    });
  });

  group('applyExternalResponse', () {
    PresenceLink linkFor(String memberId, String status, {bool? agapePresent}) =>
        PresenceLink(
          id: 't1',
          kind: kPresenceLinkKindExternal,
          sessionId: 'e1',
          sessionLabel: 'Tenue de la R∴L∴ Test',
          sessionDateLabel: 'lundi 1 janvier 2026',
          sessionType: 'Tenue ordinaire',
          sessionDegreeLabel: 'Tous',
          hasAgape: true,
          memberId: memberId,
          memberName: 'Jean DUPONT',
          status: status,
          agapePresent: agapePresent,
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          createdAt: DateTime.now(),
        );

    test('Présent ajoute le membre à attendingMemberIds', () {
      const session = ExternalSession(id: 'e1');
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusPresent),
      );
      expect(updated.attendingMemberIds, ['m1']);
    });

    test('Absent retire le membre s\'il y figurait déjà', () {
      const session = ExternalSession(id: 'e1', attendingMemberIds: ['m1', 'm2']);
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusAbsent),
      );
      expect(updated.attendingMemberIds, ['m2']);
    });

    test('un changement de Présent à Absent retire bien le membre (pas de doublon)', () {
      const session = ExternalSession(id: 'e1', attendingMemberIds: ['m1']);
      final present = applyExternalResponse(session, linkFor('m1', kPresenceStatusPresent));
      expect(present.attendingMemberIds, ['m1']);
      final absent = applyExternalResponse(present, linkFor('m1', kPresenceStatusAbsent));
      expect(absent.attendingMemberIds, isEmpty);
    });

    test('Présent + agapePresent ajoute aussi le membre à agapeIds', () {
      const session = ExternalSession(id: 'e1');
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusPresent, agapePresent: true),
      );
      expect(updated.attendingMemberIds, ['m1']);
      expect(updated.agapeIds, ['m1']);
    });

    test('Présent sans agapePresent ne touche pas agapeIds', () {
      const session = ExternalSession(id: 'e1');
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusPresent, agapePresent: false),
      );
      expect(updated.attendingMemberIds, ['m1']);
      expect(updated.agapeIds, isEmpty);
    });

    test('Absent retire le membre de agapeIds même s\'il y était (changement de réponse)', () {
      const session = ExternalSession(id: 'e1', attendingMemberIds: ['m1'], agapeIds: ['m1']);
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusAbsent),
      );
      expect(updated.attendingMemberIds, isEmpty);
      expect(updated.agapeIds, isEmpty);
    });

    test('les autres champs de la Tenue extérieure restent inchangés', () {
      const session = ExternalSession(
        id: 'e1',
        organizingLodge: 'Les Trois Vertus',
        obedience: 'GLDB',
      );
      final updated = applyExternalResponse(
        session,
        linkFor('m1', kPresenceStatusPresent),
      );
      expect(updated.organizingLodge, 'Les Trois Vertus');
      expect(updated.obedience, 'GLDB');
    });
  });
}
