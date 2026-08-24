// Statistiques d'assiduité (membres) et de fréquentation (visiteurs,
// dignitaires) — écran entièrement en lecture seule, réservé au Bureau
// (même droit que les autres écrans de gestion, voir canEditSessions).
// Un sélecteur de période (année ou « Depuis le début ») partagé par trois
// onglets — voir attendance_stats_service.dart pour le calcul.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/attendance_stats_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'directory_export_actions.dart' show saveFileLocally;

/// Convertit l'année choisie dans le sélecteur en plage `[1er janvier,
/// 31 décembre 23:59:59]` — `null` (« Depuis le début ») reste une période
/// ouverte des deux côtés. Les fonctions de calcul (attendance_stats_service)
/// raisonnent sur une période libre, pas sur une année, pour être aussi
/// réutilisables par le Rapport pour la Grande Loge (période arbitraire).
({DateTime? start, DateTime? end}) _rangeForYear(int? year) {
  if (year == null) return (start: null, end: null);
  return (start: DateTime(year, 1, 1), end: DateTime(year, 12, 31, 23, 59, 59));
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int? _year;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final years = availableStatsYears(state.sessions, state.externalSessions);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiques'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assiduité'),
              Tab(text: 'Visiteurs'),
              Tab(text: 'Dignitaires'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _PeriodSelector(
                year: _year,
                years: years,
                onChanged: (y) => setState(() => _year = y),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _MemberAttendanceTab(year: _year),
                  _VisitorFrequentationTab(year: _year),
                  _DignitaryFrequentationTab(year: _year),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int? year;
  final List<int> years;
  final ValueChanged<int?> onChanged;
  const _PeriodSelector({
    required this.year,
    required this.years,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: BrColors.backgroundDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(BrColors.radiusS),
        border: Border.all(color: BrColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: BrColors.gold),
          const SizedBox(width: 8),
          const Text('Période', style: TextStyle(color: BrColors.muted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: year,
                dropdownColor: BrColors.surface,
                style: const TextStyle(
                  color: BrColors.goldBright,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Depuis le début')),
                  for (final y in years) DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberAttendanceTab extends StatelessWidget {
  final int? year;
  const _MemberAttendanceTab({required this.year});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = _rangeForYear(year);
    final stats = computeMemberAttendance(
      state.members,
      state.sessions,
      state.externalSessions,
      start: range.start,
      end: range.end,
    );
    return _StatsScaffold(
      empty: stats.isEmpty,
      emptyText: 'Aucune tenue passée sur cette période.',
      onExport: () async {
        final bytes = buildMemberAttendanceWorkbook(stats);
        await saveFileLocally(context, _fileName('Assiduite', year), bytes);
      },
      table: DataTable(
        headingRowColor: WidgetStateProperty.all(BrColors.backgroundDark),
        columns: const [
          DataColumn(label: Text('Membre')),
          DataColumn(label: Text('Grade')),
          DataColumn(label: Text('Éligible'), numeric: true),
          DataColumn(label: Text('Présent'), numeric: true),
          DataColumn(label: Text('Excusé'), numeric: true),
          DataColumn(label: Text('Absence'), numeric: true),
          DataColumn(label: Text('Taux'), numeric: true),
          DataColumn(label: Text('Tenues ext.'), numeric: true),
          DataColumn(label: Text('Planches'), numeric: true),
          DataColumn(label: Text('Total'), numeric: true),
        ],
        rows: [
          for (final s in stats)
            DataRow(
              cells: [
                DataCell(Text(s.fullName)),
                DataCell(Text(s.grade)),
                DataCell(Text('${s.eligibleCount}')),
                DataCell(Text('${s.presentCount}')),
                DataCell(Text('${s.excusedCount}')),
                DataCell(Text('${s.unexcusedAbsences}')),
                DataCell(Text('${(s.attendanceRate * 100).toStringAsFixed(0)} %')),
                DataCell(Text('${s.externalVisits}')),
                DataCell(Text('${s.planchesCount}')),
                DataCell(Text('${s.totalEngagement}')),
              ],
            ),
        ],
      ),
    );
  }
}

class _VisitorFrequentationTab extends StatelessWidget {
  final int? year;
  const _VisitorFrequentationTab({required this.year});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = _rangeForYear(year);
    final stats = computeVisitorFrequentation(
      state.visitors,
      state.sessions,
      start: range.start,
      end: range.end,
    );
    return _StatsScaffold(
      empty: stats.isEmpty,
      emptyText: 'Aucun visiteur présent sur cette période.',
      onExport: () async {
        final bytes = buildVisitorFrequentationWorkbook(stats);
        await saveFileLocally(context, _fileName('Frequentation_Visiteurs', year), bytes);
      },
      table: DataTable(
        headingRowColor: WidgetStateProperty.all(BrColors.backgroundDark),
        columns: const [
          DataColumn(label: Text('Visiteur')),
          DataColumn(label: Text("Loge d'origine")),
          DataColumn(label: Text('Obédience')),
          DataColumn(label: Text('Visites'), numeric: true),
          DataColumn(label: Text('Dernière visite')),
        ],
        rows: [
          for (final s in stats)
            DataRow(
              cells: [
                DataCell(Text(s.fullName)),
                DataCell(Text(s.lodge)),
                DataCell(Text(s.obedience)),
                DataCell(Text('${s.visitCount}')),
                DataCell(Text(_fmtDate(s.lastVisit))),
              ],
            ),
        ],
      ),
    );
  }
}

class _DignitaryFrequentationTab extends StatelessWidget {
  final int? year;
  const _DignitaryFrequentationTab({required this.year});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final range = _rangeForYear(year);
    final stats = computeDignitaryFrequentation(
      state.dignitaries,
      state.sessions,
      start: range.start,
      end: range.end,
    );
    return _StatsScaffold(
      empty: stats.isEmpty,
      emptyText: 'Aucun dignitaire présent sur cette période.',
      onExport: () async {
        final bytes = buildDignitaryFrequentationWorkbook(stats);
        await saveFileLocally(context, _fileName('Frequentation_Dignitaires', year), bytes);
      },
      table: DataTable(
        headingRowColor: WidgetStateProperty.all(BrColors.backgroundDark),
        columns: const [
          DataColumn(label: Text('Dignitaire')),
          DataColumn(label: Text('Titre / qualité')),
          DataColumn(label: Text('Rang'), numeric: true),
          DataColumn(label: Text("Loge d'origine")),
          DataColumn(label: Text('Obédience')),
          DataColumn(label: Text('Visites'), numeric: true),
          DataColumn(label: Text('Dernière visite')),
        ],
        rows: [
          for (final s in stats)
            DataRow(
              cells: [
                DataCell(Text(s.fullName)),
                DataCell(Text(s.title)),
                DataCell(Text(s.protocolRank?.toString() ?? '')),
                DataCell(Text(s.lodge)),
                DataCell(Text(s.obedience)),
                DataCell(Text('${s.visitCount}')),
                DataCell(Text(_fmtDate(s.lastVisit))),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatsScaffold extends StatelessWidget {
  final bool empty;
  final String emptyText;
  final Widget table;
  final VoidCallback onExport;
  const _StatsScaffold({
    required this.empty,
    required this.emptyText,
    required this.table,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: empty ? null : onExport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Exporter'),
            ),
          ),
        ),
        Expanded(
          child: empty
              ? Center(
                  child: Text(emptyText, style: const TextStyle(color: BrColors.muted)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dataTableTheme: DataTableThemeData(
                          headingTextStyle: const TextStyle(
                            color: BrColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          dataTextStyle: const TextStyle(color: BrColors.text, fontSize: 12.5),
                        ),
                      ),
                      child: table,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

String _fmtDate(DateTime? d) => d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

String _fileName(String prefix, int? year) =>
    '${prefix}_${year?.toString() ?? 'Historique'}.xlsx';
