// Section « Historique » de la fiche membre : élévations de grade et
// changements de statut, datés — voir member_event.dart. La Date d'entrée
// (member.entryDate) s'affiche en première ligne de la frise sans être un
// vrai document memberEvents : elle a déjà sa propre source sur la fiche.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/member_event.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/fr_date.dart';
import '../widgets/br_decor.dart';

class MemberHistorySection extends StatelessWidget {
  final Member member;
  final List<String> grades;
  final List<String> statuses;
  const MemberHistorySection({
    super.key,
    required this.member,
    required this.grades,
    required this.statuses,
  });

  List<MemberEvent> _sortedEvents(AppState state) {
    final events = state.memberEvents.where((e) => e.memberId == member.id).toList();
    events.sort((a, b) {
      final da = a.dateTime;
      final db = b.dateTime;
      if (da == null || db == null) return 0;
      return da.compareTo(db);
    });
    return events;
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final state = context.read<AppState>();
    String type = kMemberEventElevation;
    String toValue = grades.firstWhere((g) => g != member.grade, orElse: () => grades.first);
    DateTime date = DateTime.now();
    final noteCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final options = type == kMemberEventElevation ? grades : statuses;
          if (!options.contains(toValue)) toValue = options.first;
          return AlertDialog(
            backgroundColor: BrColors.surface,
            title: const Text('Enregistrer un événement', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Type'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: type,
                        isExpanded: true,
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text),
                        items: const [
                          DropdownMenuItem(
                            value: kMemberEventElevation,
                            child: Text('Élévation de grade'),
                          ),
                          DropdownMenuItem(
                            value: kMemberEventStatusChange,
                            child: Text('Changement de statut'),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() {
                          type = v ?? type;
                          final opts = type == kMemberEventElevation ? grades : statuses;
                          toValue = opts.first;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    type == kMemberEventElevation
                        ? 'Grade actuel : ${member.grade}'
                        : 'Statut actuel : ${member.status}',
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Nouvelle valeur'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: toValue,
                        isExpanded: true,
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text),
                        items: [
                          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
                        ],
                        onChanged: (v) => setDialogState(() => toValue = v ?? toValue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(DateTime.now().year - 60),
                        lastDate: DateTime(DateTime.now().year + 1),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(date),
                        style: const TextStyle(color: BrColors.text),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(color: BrColors.text),
                    decoration: const InputDecoration(labelText: 'Note (facultative)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    final event = MemberEvent(
      id: 'mev_${DateTime.now().millisecondsSinceEpoch}',
      memberId: member.id,
      type: type,
      date: DateFormat('dd/MM/yyyy').format(date),
      fromValue: type == kMemberEventElevation ? member.grade : member.status,
      toValue: toValue,
      note: noteCtrl.text.trim(),
    );
    await state.logMemberEvent(member, event);
  }

  Future<void> _confirmDelete(BuildContext context, MemberEvent event) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text('Supprimer cet événement ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          "Seul l'historique est retiré : le grade/statut courant du membre n'est pas modifié.",
          style: TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFB7185))),
          ),
        ],
      ),
    );
    if (ok == true) await state.deleteMemberEvent(event.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final events = _sortedEvents(state);
    final entryDate = tryParseFrDate(member.entryDate);

    return BrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entryDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.login, size: 16, color: BrColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entrée le ${member.entryDate}',
                      style: const TextStyle(color: BrColors.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Aucun événement enregistré.',
                style: TextStyle(color: BrColors.muted, fontSize: 12.5),
              ),
            )
          else
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      e.type == kMemberEventElevation
                          ? Icons.trending_up
                          : Icons.swap_horiz,
                      size: 16,
                      color: BrColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.type == kMemberEventElevation
                                ? '${e.fromValue.isEmpty ? '?' : e.fromValue} → ${e.toValue}'
                                : '${e.fromValue.isEmpty ? '?' : e.fromValue} → ${e.toValue}',
                            style: const TextStyle(color: BrColors.text, fontSize: 13),
                          ),
                          Text(
                            e.note.isEmpty ? e.date : '${e.date} — ${e.note}',
                            style: const TextStyle(color: BrColors.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18, color: BrColors.muted),
                      onPressed: () => _confirmDelete(context, e),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Enregistrer un événement'),
            onPressed: () => _openAddDialog(context),
          ),
        ],
      ),
    );
  }
}
