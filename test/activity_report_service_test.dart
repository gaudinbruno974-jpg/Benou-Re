// Rapport d'activité pour la Grande Loge : chaque section agrège, sur une
// période libre (bornes incluses), des données déjà couvertes par d'autres
// tests (memberEvents, attendance_stats_service, dues) — on vérifie ici
// surtout l'assemblage et le filtrage par période propres à ce service.
import 'package:benou_re/models/agenda_item.dart';
import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/external_session.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/member_event.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/activity_report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Session pastSession({
    required String id,
    required String date,
    String degree = kApprenti,
    num troncAmount = 0,
    List<String> ordresJour = const [],
    List<AgendaItem> agendaItems = const [],
    num? chrono,
  }) {
    return Session(
      id: id,
      date: date,
      dateReprise: date,
      degree: degree,
      troncAmount: troncAmount,
      chrono: chrono,
      extra: {
        'ordresJour': ordresJour,
        if (agendaItems.isNotEmpty)
          'agendaItems': [for (final i in agendaItems) i.toMap()],
      },
    );
  }

  group('computeEffectifsSection', () {
    const m1 = Member(id: 'm1', firstName: 'A', lastName: 'A', grade: kApprenti, status: 'Actif');
    const m2 = Member(id: 'm2', firstName: 'B', lastName: 'B', grade: kMaitre, status: 'En sommeil');

    test('byGrade/byStatus reflètent la photo actuelle, pas la période', () {
      final section = computeEffectifsSection([m1, m2], const []);
      expect(section.byGrade[kApprenti], 1);
      expect(section.byGrade[kMaitre], 1);
      expect(section.byStatus['Actif'], 1);
      expect(section.byStatus['En sommeil'], 1);
    });

    test("un membre entré hors période n'apparaît pas dans newMembers", () {
      const inPeriod = Member(id: 'm3', entryDate: '10/03/2026');
      const outOfPeriod = Member(id: 'm4', entryDate: '10/03/2025');
      final section = computeEffectifsSection(
        [inPeriod, outOfPeriod],
        const [],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(section.newMembers.map((m) => m.id), ['m3']);
    });

    test('sépare élévations et changements de statut, filtrés par période', () {
      final events = [
        const MemberEvent(
          id: 'e1',
          memberId: 'm1',
          type: kMemberEventElevation,
          date: '15/06/2026',
          fromValue: kApprenti,
          toValue: kCompagnon,
        ),
        const MemberEvent(
          id: 'e2',
          memberId: 'm2',
          type: kMemberEventStatusChange,
          date: '20/06/2026',
          fromValue: 'Actif',
          toValue: 'Démissionnaire',
        ),
        const MemberEvent(
          id: 'e3',
          memberId: 'm1',
          type: kMemberEventElevation,
          date: '15/06/2025', // hors période
          fromValue: kCompagnon,
          toValue: kMaitre,
        ),
      ];
      final section = computeEffectifsSection(
        [m1, m2],
        events,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(section.elevations.map((e) => e.id), ['e1']);
      expect(section.statusChanges.map((e) => e.id), ['e2']);
    });
  });

  group('computeActivitySection', () {
    const apprenti = Member(id: 'm1', firstName: 'A', lastName: 'A', grade: kApprenti);
    const v1 = Visitor(id: 'v1', firstName: 'Jean', lastName: 'DUPONT', obedience: 'GLDF');
    const d1 = Dignitary(id: 'd1', firstName: 'Alain', lastName: 'ROUSSEAU', obedience: 'GLDF');

    test('compte les tenues internes par degré et le rayonnement extérieur', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', degree: kApprenti),
        pastSession(id: 's2', date: '2026-02-10', degree: kMaitre),
      ];
      final external = [
        ExternalSession(id: 'e1', date: '2026-03-01T00:00:00', attendingMemberIds: const ['m1']),
      ];
      final section = computeActivitySection(
        [apprenti],
        sessions,
        external,
        const [],
        const [],
      );
      expect(section.sessionsByDegree[kApprenti], 1);
      expect(section.sessionsByDegree[kMaitre], 1);
      expect(section.externalVisitCount, 1);
    });

    test('byObedience agrège Visiteurs et Dignitaires, hasMultipleObediences reflète le nombre de clés', () {
      final sessions = [
        Session(
          id: 's1',
          date: '2026-01-10',
          dateReprise: '2026-01-10',
          degree: kApprenti,
          visitorIds: const ['v1'],
          dignitaryIds: const ['d1'],
        ),
      ];
      final single = computeActivitySection([], sessions, const [], [v1], const []);
      expect(single.hasMultipleObediences, false);

      final both = computeActivitySection([], sessions, const [], [v1], [d1]);
      expect(both.byObedience['GLDF'], 2);
      expect(both.hasMultipleObediences, false); // même obédience -> une seule clé
    });

    test('aucune donnée sur la période : compteurs à 0, pas de crash', () {
      final section = computeActivitySection([], const [], const [], const [], const []);
      expect(section.sessionsByDegree, isEmpty);
      expect(section.averagePresenceRate, 0);
      expect(section.externalVisitCount, 0);
      expect(section.distinctVisitorCount, 0);
      expect(section.distinctDignitaryCount, 0);
    });
  });

  group('computeTreasurySection', () {
    test('cumule les cotisations dues/versées des années recoupant la période, exclut les exemptés', () {
      final active = Member(
        id: 'm1',
        status: 'Actif',
        duesByYear: {
          2026: const DuesYear(
            lodgeDues: 100,
            lodgeDuesPaid: true,
            lodgeDuesPaidAmount: 100,
            lodgeDuesPaidDate: '15/03/2026',
            orderDues: 50,
            orderDuesPaid: false,
          ),
        },
      );
      final exempt = Member(
        id: 'm2',
        status: 'Honoraire',
        duesByYear: {2026: const DuesYear(lodgeDues: 100)},
      );
      final section = computeTreasurySection(
        [active, exempt],
        const [],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(section.lodgeDuesTotal, 100);
      expect(section.lodgeDuesPaidTotal, 100);
      expect(section.orderDuesTotal, 50);
      expect(section.orderDuesPaidTotal, 0);
    });

    test('un versement dont la date de règlement tombe hors période ne compte pas dans "versées"', () {
      final member = Member(
        id: 'm1',
        duesByYear: {
          2026: const DuesYear(
            lodgeDues: 100,
            lodgeDuesPaid: true,
            lodgeDuesPaidAmount: 100,
            lodgeDuesPaidDate: '15/03/2025',
          ),
        },
      );
      final section = computeTreasurySection(
        [member],
        const [],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(section.lodgeDuesTotal, 100); // l'année 2026 recoupe la période
      expect(section.lodgeDuesPaidTotal, 0); // mais réglé en 2025
    });

    test('le Tronc de la Veuve additionne troncAmount des tenues de la période', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', troncAmount: 20),
        pastSession(id: 's2', date: '2025-01-10', troncAmount: 15), // hors période
      ];
      final section = computeTreasurySection(
        const [],
        sessions,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(section.troncTotal, 20);
    });
  });

  group('computePlancheEntries', () {
    const author = Member(id: 'm1', firstName: 'Jean', lastName: 'DUPONT');

    test('ne reprend que les points typés Planche, ignore les points simples', () {
      final sessions = [
        pastSession(
          id: 's1',
          date: '2026-01-10',
          chrono: 5,
          agendaItems: const [
            AgendaItem(text: 'Point A', type: kAgendaItemSimple),
            AgendaItem(
              text: 'Planche : « Le Silence » — présentée par Jea∴ DUP∴',
              type: kAgendaItemPlanche,
              authorId: 'm1',
              title: 'Le Silence',
            ),
          ],
        ),
        pastSession(id: 's2', date: '2026-02-10'), // aucun point
      ];
      final entries = computePlancheEntries(sessions, [author]);
      expect(entries.length, 1);
      expect(entries.single.title, 'Le Silence');
      expect(entries.single.authorName, 'Jean DUPONT'); // en clair, non tronqué
      expect(entries.single.sessionLabel, contains('n°5'));
    });

    test("une tenue sans typage (enregistrée avant cette fonctionnalité) ne compte aucune planche", () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', ordresJour: ['Lecture de planche à l\'ancienne']),
      ];
      final entries = computePlancheEntries(sessions, [author]);
      expect(entries, isEmpty);
    });

    test('auteur non retrouvé (membre supprimé depuis) : authorName vide, pas de crash', () {
      final sessions = [
        pastSession(
          id: 's1',
          date: '2026-01-10',
          agendaItems: const [
            AgendaItem(type: kAgendaItemPlanche, authorId: 'inconnu', title: 'X'),
          ],
        ),
      ];
      final entries = computePlancheEntries(sessions, const []);
      expect(entries.single.authorName, '');
    });

    test('triées chronologiquement et filtrées par période', () {
      final sessions = [
        pastSession(
          id: 's1',
          date: '2026-03-10',
          agendaItems: const [
            AgendaItem(type: kAgendaItemPlanche, authorId: 'm1', title: 'Tardif'),
          ],
        ),
        pastSession(
          id: 's2',
          date: '2026-01-10',
          agendaItems: const [
            AgendaItem(type: kAgendaItemPlanche, authorId: 'm1', title: 'Précoce'),
          ],
        ),
        pastSession(
          id: 's3',
          date: '2025-01-10',
          agendaItems: const [
            AgendaItem(type: kAgendaItemPlanche, authorId: 'm1', title: 'Hors période'),
          ],
        ),
      ];
      final entries = computePlancheEntries(
        sessions,
        [author],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(entries.map((e) => e.title), ['Précoce', 'Tardif']);
    });
  });

  group('planchesCountByAuthor', () {
    test('additionne par auteur et ignore les entrées sans auteur retrouvé', () {
      const entries = [
        PlancheEntry(sessionLabel: 's1', date: null, authorName: 'Jean DUPONT', title: 'A'),
        PlancheEntry(sessionLabel: 's2', date: null, authorName: 'Jean DUPONT', title: 'B'),
        PlancheEntry(sessionLabel: 's3', date: null, authorName: 'Marie MARTIN', title: 'C'),
        PlancheEntry(sessionLabel: 's4', date: null, authorName: '', title: 'D'),
      ];
      final counts = planchesCountByAuthor(entries);
      expect(counts, {'Jean DUPONT': 2, 'Marie MARTIN': 1});
    });
  });
}
