// Rapport d'activité pour la Grande Loge : agrège, sur une période libre
// (bornes incluses), ce qui est déjà enregistré ailleurs dans l'app —
// effectifs, assiduité (attendance_stats_service.dart), Trésorerie, planches
// tracées étudiées. Lecture seule : aucune donnée n'est modifiée ici.
import 'attendance_stats_service.dart';
import '../models/dignitary.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../models/member_event.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../utils/fr_date.dart';

bool _inRange(DateTime? dt, DateTime? start, DateTime? end) {
  if (dt == null) return false;
  if (start != null && dt.isBefore(start)) return false;
  if (end != null && dt.isAfter(end)) return false;
  return true;
}

// ─── 1. Effectifs ─────────────────────────────────────────────────────

class EffectifsSection {
  /// Répartition ACTUELLE (pas sur la période — une photo à la date de
  /// génération du rapport), par grade puis par statut.
  final Map<String, int> byGrade;
  final Map<String, int> byStatus;

  /// Membres dont la Date d'entrée tombe dans la période.
  final List<Member> newMembers;

  /// Élévations de grade enregistrées (memberEvents) sur la période.
  final List<MemberEvent> elevations;

  /// Changements de statut enregistrés (memberEvents) sur la période —
  /// inclut aussi bien un départ (Actif → Démissionnaire/Radié/En sommeil)
  /// qu'une réintégration.
  final List<MemberEvent> statusChanges;

  const EffectifsSection({
    required this.byGrade,
    required this.byStatus,
    required this.newMembers,
    required this.elevations,
    required this.statusChanges,
  });
}

EffectifsSection computeEffectifsSection(
  List<Member> members,
  List<MemberEvent> memberEvents, {
  DateTime? start,
  DateTime? end,
}) {
  final byGrade = <String, int>{};
  final byStatus = <String, int>{};
  for (final m in members) {
    byGrade[m.grade] = (byGrade[m.grade] ?? 0) + 1;
    byStatus[m.status] = (byStatus[m.status] ?? 0) + 1;
  }
  final newMembers = members
      .where((m) => _inRange(tryParseFrDate(m.entryDate), start, end))
      .toList();
  final periodEvents =
      memberEvents.where((e) => _inRange(e.dateTime, start, end)).toList();
  final elevations =
      periodEvents.where((e) => e.type == kMemberEventElevation).toList();
  final statusChanges =
      periodEvents.where((e) => e.type == kMemberEventStatusChange).toList();
  return EffectifsSection(
    byGrade: byGrade,
    byStatus: byStatus,
    newMembers: newMembers,
    elevations: elevations,
    statusChanges: statusChanges,
  );
}

// ─── 2. Activité et assiduité ─────────────────────────────────────────

class ActivitySection {
  final Map<String, int> sessionsByDegree;

  /// Moyenne des taux de présence individuels, en excluant les membres
  /// n'ayant été éligibles à aucune tenue de la période (voir
  /// MemberAttendanceStat.attendanceRate) — sinon un membre sans encore de
  /// tenue tirerait la moyenne vers 0 sans rapport avec son assiduité.
  final double averagePresenceRate;

  /// Nombre total de participations (un membre visitant 3 tenues
  /// extérieures compte pour 3), pas le nombre de membres distincts.
  final int externalVisitCount;

  final int distinctVisitorCount;
  final int distinctDignitaryCount;

  /// Obédience -> nombre de visiteurs+dignitaires distincts de cette
  /// obédience — à n'afficher que si elle compte plus d'une entrée (voir
  /// [hasMultipleObediences]).
  final Map<String, int> byObedience;

  const ActivitySection({
    required this.sessionsByDegree,
    required this.averagePresenceRate,
    required this.externalVisitCount,
    required this.distinctVisitorCount,
    required this.distinctDignitaryCount,
    required this.byObedience,
  });

  bool get hasMultipleObediences => byObedience.length > 1;
}

ActivitySection computeActivitySection(
  List<Member> members,
  List<Session> sessions,
  List<ExternalSession> externalSessions,
  List<Visitor> visitors,
  List<Dignitary> dignitaries, {
  DateTime? start,
  DateTime? end,
}) {
  final pastSessions = pastSessionsInRange(sessions, start: start, end: end);
  final sessionsByDegree = <String, int>{};
  for (final s in pastSessions) {
    sessionsByDegree[s.degree] = (sessionsByDegree[s.degree] ?? 0) + 1;
  }

  final attendance = computeMemberAttendance(
    members,
    sessions,
    externalSessions,
    start: start,
    end: end,
  ).where((s) => s.eligibleCount > 0).toList();
  final averageRate = attendance.isEmpty
      ? 0.0
      : attendance.map((s) => s.attendanceRate).reduce((a, b) => a + b) /
          attendance.length;

  final pastExternal =
      pastExternalSessionsInRange(externalSessions, start: start, end: end);
  final externalVisitCount =
      pastExternal.fold<int>(0, (sum, s) => sum + s.attendingMemberIds.length);

  final visitorStats =
      computeVisitorFrequentation(visitors, sessions, start: start, end: end);
  final dignitaryStats = computeDignitaryFrequentation(
    dignitaries,
    sessions,
    start: start,
    end: end,
  );

  final byObedience = <String, int>{};
  void tally(String obedience) {
    final key = obedience.trim().isEmpty ? 'Non renseignée' : obedience.trim();
    byObedience[key] = (byObedience[key] ?? 0) + 1;
  }

  for (final v in visitorStats) {
    tally(v.obedience);
  }
  for (final d in dignitaryStats) {
    tally(d.obedience);
  }

  return ActivitySection(
    sessionsByDegree: sessionsByDegree,
    averagePresenceRate: averageRate,
    externalVisitCount: externalVisitCount,
    distinctVisitorCount: visitorStats.length,
    distinctDignitaryCount: dignitaryStats.length,
    byObedience: byObedience,
  );
}

// ─── 3. Trésorerie ────────────────────────────────────────────────────

class TreasurySection {
  final num lodgeDuesTotal;
  final num lodgeDuesPaidTotal;
  final num orderDuesTotal;
  final num orderDuesPaidTotal;
  final num troncTotal;

  const TreasurySection({
    required this.lodgeDuesTotal,
    required this.lodgeDuesPaidTotal,
    required this.orderDuesTotal,
    required this.orderDuesPaidTotal,
    required this.troncTotal,
  });
}

/// Années civiles dont l'intervalle `[1er janvier, 31 décembre]` recoupe
/// `[start, end]` — une cotisation est un montant annuel, non proratisable
/// au jour près. `null` de part et d'autre couvre toutes les années
/// enregistrées.
Set<int> _yearsOverlapping(
  Iterable<int> knownYears,
  DateTime? start,
  DateTime? end,
) {
  return knownYears.where((y) {
    final yearStart = DateTime(y, 1, 1);
    final yearEnd = DateTime(y, 12, 31, 23, 59, 59);
    if (start != null && yearEnd.isBefore(start)) return false;
    if (end != null && yearStart.isAfter(end)) return false;
    return true;
  }).toSet();
}

/// Cotisations dues et versées sur la période, et solde du Tronc de la
/// Veuve. Les montants « dus » reprennent les années civiles recoupant la
/// période (voir [_yearsOverlapping]) ; les montants « versés » ne comptent
/// que les lignes intégralement soldées dont la date de règlement tombe
/// dans la période — un versement partiel n'a pas de date de règlement
/// suivie par l'application (voir DuesYear.lodgeDuesPaidDate) et ne peut
/// donc pas être daté précisément : il n'est pas inclus. Le Tronc, lui, est
/// la somme de `troncAmount` des tenues de la période (pas cumulatif depuis
/// toujours).
TreasurySection computeTreasurySection(
  List<Member> members,
  List<Session> sessions, {
  DateTime? start,
  DateTime? end,
}) {
  final knownYears = <int>{
    for (final m in members) ...m.duesByYear.keys,
  };
  final years = _yearsOverlapping(knownYears, start, end);

  num lodgeDuesTotal = 0;
  num lodgeDuesPaidTotal = 0;
  num orderDuesTotal = 0;
  num orderDuesPaidTotal = 0;

  for (final m in members) {
    if (m.isExemptFromDues) continue;
    for (final y in years) {
      final dues = m.duesByYear[y];
      if (dues == null) continue;
      lodgeDuesTotal += dues.lodgeDues;
      orderDuesTotal += dues.orderDues;
      if (dues.lodgeDuesPaid && _inRange(tryParseFrDate(dues.lodgeDuesPaidDate), start, end)) {
        lodgeDuesPaidTotal += dues.lodgeDues;
      }
      if (dues.orderDuesPaid && _inRange(tryParseFrDate(dues.orderDuesPaidDate), start, end)) {
        orderDuesPaidTotal += dues.orderDues;
      }
    }
  }

  final troncTotal = pastSessionsInRange(sessions, start: start, end: end)
      .fold<num>(0, (sum, s) => sum + s.troncAmount);

  return TreasurySection(
    lodgeDuesTotal: lodgeDuesTotal,
    lodgeDuesPaidTotal: lodgeDuesPaidTotal,
    orderDuesTotal: orderDuesTotal,
    orderDuesPaidTotal: orderDuesPaidTotal,
    troncTotal: troncTotal,
  );
}

// ─── 4. Planches tracées étudiées ─────────────────────────────────────

class PlancheEntry {
  final String sessionLabel;
  final DateTime? date;
  final String authorName;
  final String title;

  /// Degré de la tenue où la planche a été présentée (Apprenti/Compagnon/
  /// Maître, voir Session.degree) — pas forcément le grade de l'auteur.
  final String degree;

  const PlancheEntry({
    required this.sessionLabel,
    required this.date,
    required this.authorName,
    required this.title,
    required this.degree,
  });
}

String _sessionLabel(Session s) {
  final chronoLabel = s.chrono != null
      ? '${s.chrono!.toInt()}'
      : (s.sessionNumber ?? '');
  final dateLabel = s.dateTime == null
      ? 'date inconnue'
      : '${s.dateTime!.day.toString().padLeft(2, '0')}/'
          '${s.dateTime!.month.toString().padLeft(2, '0')}/'
          '${s.dateTime!.year}';
  return 'Tenue ${chronoLabel.isEmpty ? '' : 'n°$chronoLabel '}du $dateLabel';
}

/// Pour chaque tenue de la période, les points d'ordre du jour typés
/// « Planche » (voir agenda_item.dart) — dans l'ordre chronologique. Une
/// tenue dont l'ordre du jour n'a pas ce typage (enregistrée avant son
/// introduction) ne compte simplement aucune planche, sans erreur.
/// [authorName] reprend le nom complet, non tronqué : ce document reste
/// interne au Bureau. Vide si l'auteur n'a pas pu être retrouvé (membre
/// supprimé depuis).
List<PlancheEntry> computePlancheEntries(
  List<Session> sessions,
  List<Member> members, {
  DateTime? start,
  DateTime? end,
}) {
  final past = pastSessionsInRange(sessions, start: start, end: end)
    ..sort((a, b) {
      final da = a.dateTime;
      final db = b.dateTime;
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
  final membersById = {for (final m in members) m.id: m};
  final entries = <PlancheEntry>[];
  for (final s in past) {
    final label = _sessionLabel(s);
    for (final item in s.agendaItems) {
      if (!item.isPlanche) continue;
      entries.add(
        PlancheEntry(
          sessionLabel: label,
          date: s.dateTime,
          authorName: membersById[item.authorId]?.fullName ?? '',
          title: item.title,
          degree: s.degree,
        ),
      );
    }
  }
  return entries;
}

/// Nombre de planches par auteur (nom complet), pour le sous-total du
/// Rapport pour la Grande Loge — les entrées sans auteur retrouvé sont
/// ignorées (déjà signalées individuellement dans la liste détaillée).
Map<String, int> planchesCountByAuthor(List<PlancheEntry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    if (e.authorName.isEmpty) continue;
    counts[e.authorName] = (counts[e.authorName] ?? 0) + 1;
  }
  return counts;
}
