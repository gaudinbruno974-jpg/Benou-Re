// Tenues d'un corps de Hauts Grades (IAH-MES) — liste + génération de la
// convocation PDF (voir hg_pdf_service.dart). MAA-Kherou n'est pas encore
// câblé sur cet écran (gabarit de convocation à définir séparément).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../services/hg_body_service.dart';
import '../services/hg_pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_hg_session_edit_screen.dart';

String _formatDate(HgSession s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date non définie';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

class GrandeLogeHgSessionsScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgSessionsScreen({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditHgBody(context.watch<AppState>().currentUser, body);
    return Scaffold(
      appBar: AppBar(title: Text('Tenues — ${body.label}')),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              backgroundColor: BrColors.teal,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle tenue'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgSessionEditScreen(body: body),
                ),
              ),
            )
          : null,
      body: StreamBuilder<List<HgSession>>(
        stream: HgBodyService.instance.sessionsStream(body),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snap.error}',
                style: const TextStyle(color: BrColors.error),
              ),
            );
          }
          final sessions = snap.data;
          if (sessions == null) {
            return const Center(
              child: CircularProgressIndicator(color: BrColors.gold),
            );
          }
          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                'Aucune tenue.',
                style: TextStyle(color: BrColors.muted),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, i) => _SessionCard(
              body: body,
              session: sessions[i],
              canEdit: canEdit,
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatefulWidget {
  final HgBody body;
  final HgSession session;
  final bool canEdit;
  const _SessionCard({
    required this.body,
    required this.session,
    required this.canEdit,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _generating = false;

  Future<void> _generateConvocation() async {
    setState(() => _generating = true);
    try {
      final bytes = await buildIahMesConvocationPdf(widget.session);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'Convocation ${widget.body.label}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final degreeName = kIahMesDegreeNames[s.degree] ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.canEdit
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GrandeLogeHgSessionEditScreen(
                          body: widget.body,
                          session: s,
                        ),
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(s),
                    style: const TextStyle(
                      color: BrColors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.degree}e degré — $degreeName',
                    style: const TextStyle(
                      color: BrColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  if (s.themeTitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      s.themeTitle.trim(),
                      style: const TextStyle(
                        color: BrColors.goldBright,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _generateConvocation,
                icon: _generating
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Convocation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
