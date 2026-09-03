// Statistiques d'assiduité (membres) et de fréquentation (visiteurs,
// dignitaires) : agrège ce qui est déjà enregistré sur les tenues de la
// Loge (presentIds/excusedIds/visitorIds/dignitaryIds, y compris une fois
// suspendues) et sur le Registre des Tenues extérieures
// (attendingMemberIds) — écran entièrement en lecture seule, aucune donnée
// n'est modifiée ici. Voir statistics_screen.dart pour l'écran.
import '../models/dignitary.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import 'xlsx_codec.dart';

/// Année d'une tenue (interne ou extérieure), ou `null` si sa date n'est
/// pas renseignée — exclue de tout filtrage par année dans ce cas.
int? _yearOf(DateTime? dt) => dt?.year;

/// Vrai si [dt] tombe dans `[start, end]`, bornes incluses — `null` de part
/// et d'autre laisse la borne correspondante ouverte (voir
/// [pastSessionsInRange]/[pastExternalSessionsInRange]).
bool _inRange(DateTime? dt, DateTime? start, DateTime? end) {
  if (dt == null) return false;
  if (start != null && dt.isBefore(start)) return false;
  if (end != null && dt.isAfter(end)) return false;
  return true;
}

/// Tenues de la Loge déjà tenues (une tenue à venir ne peut ni compter en
/// présence ni en absence), dont la date tombe dans `[start, end]` (bornes
/// incluses ; `null` = période ouverte de ce côté — utilisé par
/// statistics_screen.dart, converti depuis une année, et par
/// activity_report_service.dart, sur une période libre).
List<Session> pastSessionsInRange(
  List<Session> sessions, {
  DateTime? start,
  DateTime? end,
}) {
  return sessions
      .where((s) => s.isSuspended && _inRange(s.dateTime, start, end))
      .toList();
}

List<ExternalSession> pastExternalSessionsInRange(
  List<ExternalSession> externalSessions, {
  DateTime? start,
  DateTime? end,
}) {
  return externalSessions
      .where((s) => s.isPast && _inRange(s.dateTime, start, end))
      .toList();
}

/// Toutes les années disponibles (tenues internes et extérieures
/// confondues), triées de la plus récente à la plus ancienne — pour peupler
/// le sélecteur de période, à côté de l'option « Depuis le début » (`null`).
List<int> availableStatsYears(
  List<Session> sessions,
  List<ExternalSession> externalSessions,
) {
  final years = <int>{
    for (final s in sessions)
      if (_yearOf(s.dateTime) != null) _yearOf(s.dateTime)!,
    for (final s in externalSessions)
      if (_yearOf(s.dateTime) != null) _yearOf(s.dateTime)!,
  };
  final list = years.toList()..sort((a, b) => b.compareTo(a));
  return list;
}

class MemberAttendanceStat {
  final String memberId;
  final String fullName;
  final String grade;
  final int eligibleCount;
  final int presentCount;
  final int excusedCount;
  final int externalVisits;

  /// Points d'ordre du jour typés « Planche » dont ce membre est l'auteur,
  /// toutes tenues confondues sur la période (pas seulement celles où il
  /// était éligible) — affiché à part, jamais inclus dans
  /// [totalEngagement] : présence et prise de parole ne se mesurent pas de
  /// la même façon.
  final int planchesCount;

  const MemberAttendanceStat({
    required this.memberId,
    required this.fullName,
    required this.grade,
    required this.eligibleCount,
    required this.presentCount,
    required this.excusedCount,
    required this.externalVisits,
    required this.planchesCount,
  });

  /// Absence non excusée = éligible − présent − excusé — jamais stockée,
  /// toujours déduite des trois autres compteurs.
  int get unexcusedAbsences => eligibleCount - presentCount - excusedCount;

  /// Présent / éligible, 0 si le membre n'était éligible à aucune tenue de
  /// la période (jamais de division par zéro).
  double get attendanceRate =>
      eligibleCount == 0 ? 0 : presentCount / eligibleCount;

  /// Tenues internes présentes + tenues extérieures visitées.
  int get totalEngagement => presentCount + externalVisits;
}

/// Assiduité de chaque membre de la Loge sur la période `[start, end]`
/// (bornes incluses, `null` = ouverte) — Triée par taux de présence
/// décroissant.
List<MemberAttendanceStat> computeMemberAttendance(
  List<Member> members,
  List<Session> sessions,
  List<ExternalSession> externalSessions, {
  DateTime? start,
  DateTime? end,
}) {
  final pastSessions = pastSessionsInRange(sessions, start: start, end: end);
  final pastExternal =
      pastExternalSessionsInRange(externalSessions, start: start, end: end);

  final stats = <MemberAttendanceStat>[];
  for (final m in members) {
    final memberRank = Session.degreeRank(m.grade);
    var eligible = 0;
    var present = 0;
    var excused = 0;
    for (final s in pastSessions) {
      if (Session.degreeRank(s.degree) > memberRank) continue;
      eligible++;
      if (s.presentIds.contains(m.id)) {
        present++;
      } else if (s.excusedIds.contains(m.id)) {
        excused++;
      }
    }
    final externalVisits =
        pastExternal.where((s) => s.attendingMemberIds.contains(m.id)).length;
    var planches = 0;
    for (final s in pastSessions) {
      for (final item in s.agendaItems) {
        if (item.isPlanche && item.authorId == m.id) planches++;
      }
    }
    stats.add(
      MemberAttendanceStat(
        memberId: m.id,
        fullName: m.fullName,
        grade: m.grade,
        eligibleCount: eligible,
        presentCount: present,
        excusedCount: excused,
        externalVisits: externalVisits,
        planchesCount: planches,
      ),
    );
  }
  stats.sort((a, b) => b.attendanceRate.compareTo(a.attendanceRate));
  return stats;
}

class _Frequentation {
  final String id;
  final String fullName;
  final String lodge;
  final String obedience;
  final int visitCount;
  final DateTime? lastVisit;
  const _Frequentation({
    required this.id,
    required this.fullName,
    required this.lodge,
    required this.obedience,
    required this.visitCount,
    required this.lastVisit,
  });
}

class VisitorFrequentation extends _Frequentation {
  const VisitorFrequentation({
    required super.id,
    required super.fullName,
    required super.lodge,
    required super.obedience,
    required super.visitCount,
    required super.lastVisit,
  });
}

class DignitaryFrequentation extends _Frequentation {
  final String title;
  final int? protocolRank;
  const DignitaryFrequentation({
    required super.id,
    required super.fullName,
    required super.lodge,
    required super.obedience,
    required super.visitCount,
    required super.lastVisit,
    required this.title,
    required this.protocolRank,
  });
}

/// Fréquentation de chaque Visiteur présent au moins une fois sur la
/// période — triée par nombre de visites décroissant. Un visiteur jamais
/// présent sur la période n'apparaît pas.
List<VisitorFrequentation> computeVisitorFrequentation(
  List<Visitor> visitors,
  List<Session> sessions, {
  DateTime? start,
  DateTime? end,
}) {
  final pastSessions = pastSessionsInRange(sessions, start: start, end: end);
  final result = <VisitorFrequentation>[];
  for (final v in visitors) {
    final visits = pastSessions.where((s) => s.visitorIds.contains(v.id)).toList();
    if (visits.isEmpty) continue;
    final lastVisit = visits
        .map((s) => s.dateTime)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    result.add(
      VisitorFrequentation(
        id: v.id,
        fullName: v.fullName,
        lodge: v.lodge,
        obedience: v.obedience,
        visitCount: visits.length,
        lastVisit: lastVisit,
      ),
    );
  }
  result.sort((a, b) => b.visitCount.compareTo(a.visitCount));
  return result;
}

/// Même principe que [computeVisitorFrequentation], pour les Dignitaires —
/// avec en plus le titre/qualité et le rang protocolaire.
List<DignitaryFrequentation> computeDignitaryFrequentation(
  List<Dignitary> dignitaries,
  List<Session> sessions, {
  DateTime? start,
  DateTime? end,
}) {
  final pastSessions = pastSessionsInRange(sessions, start: start, end: end);
  final result = <DignitaryFrequentation>[];
  for (final d in dignitaries) {
    final visits =
        pastSessions.where((s) => s.dignitaryIds.contains(d.id)).toList();
    if (visits.isEmpty) continue;
    final lastVisit = visits
        .map((s) => s.dateTime)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    result.add(
      DignitaryFrequentation(
        id: d.id,
        fullName: d.fullName,
        lodge: d.lodge,
        obedience: d.obedience,
        visitCount: visits.length,
        lastVisit: lastVisit,
        title: d.title,
        protocolRank: d.protocolRank,
      ),
    );
  }
  result.sort((a, b) => b.visitCount.compareTo(a.visitCount));
  return result;
}

// ─── Export .xlsx ─────────────────────────────────────────────────────

String _pct(double v) => '${(v * 100).toStringAsFixed(1)} %';
String _dateOrEmpty(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

const List<String> kMemberAttendanceHeaders = [
  'Nom complet',
  'Grade',
  'Tenues éligibles',
  'Présent',
  'Excusé',
  'Absence non excusée',
  'Taux de présence',
  'Tenues extérieures visitées',
  'Planches présentées',
  'Total engagement',
];

List<int> buildMemberAttendanceWorkbook(List<MemberAttendanceStat> stats) {
  return buildXlsx({
    'Assiduité': [
      kMemberAttendanceHeaders,
      for (final s in stats)
        [
          s.fullName,
          s.grade,
          '${s.eligibleCount}',
          '${s.presentCount}',
          '${s.excusedCount}',
          '${s.unexcusedAbsences}',
          _pct(s.attendanceRate),
          '${s.externalVisits}',
          '${s.planchesCount}',
          '${s.totalEngagement}',
        ],
    ],
  });
}

const List<String> kVisitorFrequentationHeaders = [
  'Nom complet',
  "Loge d'origine",
  'Obédience',
  'Visites',
  'Dernière visite',
];

List<int> buildVisitorFrequentationWorkbook(List<VisitorFrequentation> stats) {
  return buildXlsx({
    'Fréquentation Visiteurs': [
      kVisitorFrequentationHeaders,
      for (final s in stats)
        [
          s.fullName,
          s.lodge,
          s.obedience,
          '${s.visitCount}',
          _dateOrEmpty(s.lastVisit),
        ],
    ],
  });
}

const List<String> kDignitaryFrequentationHeaders = [
  'Nom complet',
  'Titre / qualité',
  'Rang protocolaire',
  "Loge d'origine",
  'Obédience',
  'Visites',
  'Dernière visite',
];

List<int> buildDignitaryFrequentationWorkbook(
  List<DignitaryFrequentation> stats,
) {
  return buildXlsx({
    'Fréquentation Dignitaires': [
      kDignitaryFrequentationHeaders,
      for (final s in stats)
        [
          s.fullName,
          s.title,
          s.protocolRank?.toString() ?? '',
          s.lodge,
          s.obedience,
          '${s.visitCount}',
          _dateOrEmpty(s.lastVisit),
        ],
    ],
  });
}

/// Classeur combiné (3 feuilles), archivé sur Drive à chaque export d'un des
/// trois onglets de la page Statistiques — voir statistics_screen.dart.
List<int> buildStatsWorkbook({
  required List<MemberAttendanceStat> memberStats,
  required List<VisitorFrequentation> visitorStats,
  required List<DignitaryFrequentation> dignitaryStats,
}) {
  return buildXlsx({
    'Assiduité': [
      kMemberAttendanceHeaders,
      for (final s in memberStats)
        [
          s.fullName,
          s.grade,
          '${s.eligibleCount}',
          '${s.presentCount}',
          '${s.excusedCount}',
          '${s.unexcusedAbsences}',
          _pct(s.attendanceRate),
          '${s.externalVisits}',
          '${s.planchesCount}',
          '${s.totalEngagement}',
        ],
    ],
    'Fréquentation Visiteurs': [
      kVisitorFrequentationHeaders,
      for (final s in visitorStats)
        [
          s.fullName,
          s.lodge,
          s.obedience,
          '${s.visitCount}',
          _dateOrEmpty(s.lastVisit),
        ],
    ],
    'Fréquentation Dignitaires': [
      kDignitaryFrequentationHeaders,
      for (final s in dignitaryStats)
        [
          s.fullName,
          s.title,
          s.protocolRank?.toString() ?? '',
          s.lodge,
          s.obedience,
          '${s.visitCount}',
          _dateOrEmpty(s.lastVisit),
        ],
    ],
  });
}
