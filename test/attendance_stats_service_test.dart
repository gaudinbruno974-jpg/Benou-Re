// Statistiques d'assiduité (membres) et de fréquentation (visiteurs,
// dignitaires) : taux de présence (avec le cas d'un membre non éligible,
// exclu du dénominateur), et agrégation du nombre de visites.
import 'package:benou_re/models/agenda_item.dart';
import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/external_session.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/attendance_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Session pastSession({
    required String id,
    required String date,
    String degree = kApprenti,
    List<String> presentIds = const [],
    List<String> excusedIds = const [],
    List<String> visitorIds = const [],
    List<String> dignitaryIds = const [],
    List<AgendaItem> agendaItems = const [],
  }) {
    return Session(
      id: id,
      date: date,
      dateReprise: date,
      degree: degree,
      presentIds: presentIds,
      excusedIds: excusedIds,
      visitorIds: visitorIds,
      dignitaryIds: dignitaryIds,
      extra: {
        if (agendaItems.isNotEmpty)
          'agendaItems': [for (final i in agendaItems) i.toMap()],
      },
    );
  }

  Session futureSession({required String id, String degree = kApprenti}) {
    final future = DateTime.now().add(const Duration(days: 30)).toIso8601String();
    return Session(id: id, date: future, dateReprise: future, degree: degree);
  }

  group('computeMemberAttendance', () {
    const apprenti = Member(id: 'm1', firstName: 'A', lastName: 'A', grade: kApprenti);
    const maitre = Member(id: 'm2', firstName: 'B', lastName: 'B', grade: kMaitre);

    test(
      "une tenue d'un degré supérieur au grade du membre ne compte pas dans son dénominateur",
      () {
        final sessions = [
          pastSession(id: 's1', date: '2026-01-10', degree: kMaitre, presentIds: ['m1', 'm2']),
        ];
        final stats = computeMemberAttendance([apprenti, maitre], sessions, const []);
        final apprentiStat = stats.firstWhere((s) => s.memberId == 'm1');
        final maitreStat = stats.firstWhere((s) => s.memberId == 'm2');
        // L'Apprenti n'est pas éligible à une tenue au 3e degré, même s'il a
        // été (à tort) coché présent : elle n'entre pas dans son calcul.
        expect(apprentiStat.eligibleCount, 0);
        expect(apprentiStat.presentCount, 0);
        expect(apprentiStat.attendanceRate, 0);
        // Le Maître, lui, était bien éligible et présent.
        expect(maitreStat.eligibleCount, 1);
        expect(maitreStat.presentCount, 1);
        expect(maitreStat.attendanceRate, 1);
      },
    );

    test('un grade supérieur reste éligible à une tenue de degré inférieur', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', degree: kApprenti, presentIds: ['m2']),
      ];
      final stats = computeMemberAttendance([maitre], sessions, const []);
      expect(stats.single.eligibleCount, 1);
      expect(stats.single.presentCount, 1);
    });

    test('une tenue à venir ne compte ni en présence ni en absence', () {
      final sessions = [futureSession(id: 's1')];
      final stats = computeMemberAttendance([apprenti], sessions, const []);
      expect(stats.single.eligibleCount, 0);
    });

    test('taux de présence = présent / éligible, excusé et absence distincts', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', presentIds: ['m1']),
        pastSession(id: 's2', date: '2026-02-10', excusedIds: ['m1']),
        pastSession(id: 's3', date: '2026-03-10'), // ni présent ni excusé
      ];
      final stats = computeMemberAttendance([apprenti], sessions, const []);
      final s = stats.single;
      expect(s.eligibleCount, 3);
      expect(s.presentCount, 1);
      expect(s.excusedCount, 1);
      expect(s.unexcusedAbsences, 1);
      expect(s.attendanceRate, closeTo(1 / 3, 0.0001));
    });

    test('0 tenue éligible donne un taux de 0, pas une division par zéro', () {
      final stats = computeMemberAttendance([apprenti], const [], const []);
      expect(stats.single.eligibleCount, 0);
      expect(stats.single.attendanceRate, 0);
    });

    test('les visites de Tenues extérieures s\'ajoutent au total, séparément du taux interne', () {
      final external = [
        ExternalSession(
          id: 'e1',
          date: DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
          attendingMemberIds: const ['m1'],
        ),
      ];
      final stats = computeMemberAttendance([apprenti], const [], external);
      final s = stats.single;
      expect(s.externalVisits, 1);
      expect(s.totalEngagement, 1); // 0 présent interne + 1 visite externe
    });

    test('le filtre par période exclut les tenues hors bornes', () {
      final sessions = [
        pastSession(id: 's1', date: '2025-06-01', presentIds: ['m1']),
        pastSession(id: 's2', date: '2026-06-01', presentIds: ['m1']),
      ];
      final stats2026 = computeMemberAttendance(
        [apprenti],
        sessions,
        const [],
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 12, 31, 23, 59, 59),
      );
      expect(stats2026.single.eligibleCount, 1);
      final statsAll = computeMemberAttendance([apprenti], sessions, const []);
      expect(statsAll.single.eligibleCount, 2);
    });

    test(
      'compte les planches présentées par le membre, toutes tenues confondues, hors du total engagement',
      () {
        final sessions = [
          pastSession(
            id: 's1',
            date: '2026-01-10',
            degree: kMaitre, // l'apprenti n'y est pas éligible, mais peut y présenter
            agendaItems: const [
              AgendaItem(type: kAgendaItemPlanche, authorId: 'm1', title: 'A'),
              AgendaItem(type: kAgendaItemSimple, title: 'Point classique'),
            ],
          ),
          pastSession(
            id: 's2',
            date: '2026-02-10',
            agendaItems: const [
              AgendaItem(type: kAgendaItemPlanche, authorId: 'm1', title: 'B'),
              AgendaItem(type: kAgendaItemPlanche, authorId: 'm2', title: 'C'),
            ],
          ),
        ];
        final stats = computeMemberAttendance([apprenti], sessions, const []);
        final s = stats.single;
        expect(s.planchesCount, 2);
        // Aucune présence pointée sur ces tenues : le total d'engagement
        // reste 0, les planches ne s'y ajoutent pas.
        expect(s.totalEngagement, 0);
      },
    );

    test('trié par taux de présence décroissant', () {
      const low = Member(id: 'm3', firstName: 'C', lastName: 'C', grade: kApprenti);
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', presentIds: ['m1']),
        pastSession(id: 's2', date: '2026-02-10'),
      ];
      final stats = computeMemberAttendance([low, apprenti], sessions, const []);
      expect(stats.first.memberId, 'm1');
    });
  });

  group('computeVisitorFrequentation', () {
    const v1 = Visitor(id: 'v1', firstName: 'Jean', lastName: 'DUPONT', lodge: 'A', obedience: 'GLDF');
    const v2 = Visitor(id: 'v2', firstName: 'Marie', lastName: 'MARTIN', lodge: 'B', obedience: 'GLDF');
    const neverVisited = Visitor(id: 'v3', firstName: 'Paul', lastName: 'DURAND');

    test('un visiteur jamais présent sur la période n\'apparaît pas', () {
      final sessions = [pastSession(id: 's1', date: '2026-01-10', visitorIds: ['v1'])];
      final stats = computeVisitorFrequentation([v1, neverVisited], sessions);
      expect(stats.map((s) => s.id), ['v1']);
    });

    test('compte le nombre de tenues où le visiteur était présent', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', visitorIds: ['v1']),
        pastSession(id: 's2', date: '2026-02-10', visitorIds: ['v1']),
        pastSession(id: 's3', date: '2026-03-10', visitorIds: ['v2']),
      ];
      final stats = computeVisitorFrequentation([v1, v2], sessions);
      expect(stats.firstWhere((s) => s.id == 'v1').visitCount, 2);
      expect(stats.firstWhere((s) => s.id == 'v2').visitCount, 1);
    });

    test('retient la date de la visite la plus récente', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', visitorIds: ['v1']),
        pastSession(id: 's2', date: '2026-05-20', visitorIds: ['v1']),
      ];
      final stats = computeVisitorFrequentation([v1], sessions);
      expect(stats.single.lastVisit, DateTime.parse('2026-05-20'));
    });

    test('triée par nombre de visites décroissant', () {
      final sessions = [
        pastSession(id: 's1', date: '2026-01-10', visitorIds: ['v2']),
        pastSession(id: 's2', date: '2026-02-10', visitorIds: ['v1']),
        pastSession(id: 's3', date: '2026-03-10', visitorIds: ['v1']),
      ];
      final stats = computeVisitorFrequentation([v1, v2], sessions);
      expect(stats.first.id, 'v1');
    });
  });

  group('computeDignitaryFrequentation', () {
    const d1 = Dignitary(
      id: 'd1',
      firstName: 'Alain',
      lastName: 'ROUSSEAU',
      title: 'Grand Maître Adjoint',
      lodge: 'Les Cœurs Réunis',
      protocolRank: 1,
    );

    test('reprend le titre et le rang protocolaire', () {
      final sessions = [pastSession(id: 's1', date: '2026-01-10', dignitaryIds: ['d1'])];
      final stats = computeDignitaryFrequentation([d1], sessions);
      expect(stats.single.title, 'Grand Maître Adjoint');
      expect(stats.single.protocolRank, 1);
      expect(stats.single.visitCount, 1);
    });
  });

  group('availableStatsYears', () {
    test('agrège les années des tenues internes et extérieures, sans doublon', () {
      final sessions = [pastSession(id: 's1', date: '2026-01-10')];
      final external = [
        ExternalSession(id: 'e1', date: '2025-06-01T00:00:00'),
        ExternalSession(id: 'e2', date: '2026-06-01T00:00:00'),
      ];
      final years = availableStatsYears(sessions, external);
      expect(years, [2026, 2025]); // plus récent en premier
    });
  });
}
