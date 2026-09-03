// Rapport d'activité pour la Grande Loge : deux dates (période libre,
// bornes incluses), génération directe du PDF sans écran intermédiaire —
// voir buildActivityReportPdf (pdf_service.dart) pour l'agrégation.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class ActivityReportScreen extends StatefulWidget {
  const ActivityReportScreen({super.key});

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  DateTime? _start;
  DateTime? _end;
  bool _generating = false;

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  bool get _canGenerate => _start != null && _end != null && !_end!.isBefore(_start!);

  Future<void> _generate() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generating = true);
    try {
      final Uint8List bytes = await buildActivityReportPdf(
        start: _start!,
        end: _end!,
        members: state.members,
        sessions: state.sessions,
        externalSessions: state.externalSessions,
        visitors: state.visitors,
        dignitaries: state.dignitaries,
        memberEvents: state.memberEvents,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'RapportActivite.pdf',
      );
      final df = DateFormat('dd MM yy');
      final fileName = 'Rapport activite ${LodgeConfig.current.name} '
          '${df.format(_start!)} au ${df.format(_end!)}.pdf';
      try {
        await DriveService.instance.archiveActivityReportDocument(
          fileName: fileName,
          bytes: bytes,
        );
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Archivage Drive : $e')));
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport pour la Grande Loge')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BrCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrSectionTitle('PÉRIODE COUVERTE', icon: Icons.date_range_outlined),
                  const SizedBox(height: 6),
                  const Text(
                    'Effectifs, activité et assiduité, trésorerie, planches tracées '
                    'étudiées : le rapport couvre les tenues et opérations enregistrées '
                    'entre ces deux dates (bornes incluses).',
                    style: TextStyle(color: BrColors.muted, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Du',
                          date: _start,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Au',
                          date: _end,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  if (_start != null && _end != null && _end!.isBefore(_start!)) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'La date de fin doit être postérieure à la date de début.',
                      style: TextStyle(color: BrColors.menuTresorerie, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: (_canGenerate && !_generating) ? _generate : null,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_generating ? 'Génération…' : 'Générer le PDF'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BrColors.radiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: BrColors.backgroundDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(BrColors.radiusS),
          border: Border.all(color: BrColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: BrColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: BrColors.muted, fontSize: 11)),
                  Text(
                    date == null ? 'Choisir' : DateFormat('dd/MM/yyyy').format(date!),
                    style: const TextStyle(
                      color: BrColors.goldBright,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
