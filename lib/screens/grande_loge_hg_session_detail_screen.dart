// Fiche détail d'une tenue d'un corps de Hauts Grades — même principe que
// SessionDetailScreen (sessions_screen.dart, loges bleues) : infos de la
// tenue, présents/excusés/visiteurs/dignitaires, section Documents avec
// tous les boutons (présences, invitations, annonce des dignitaires,
// émargement, planche, PDF, archivage Drive, annuler, supprimer).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_session.dart' show kIahMesDegreeNames;
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../services/hg_drive_folders.dart';
import '../services/hg_pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_hg_dignitaires_announce_screen.dart';
import 'grande_loge_hg_emargement_screen.dart';
import 'grande_loge_hg_planche_screen.dart';
import 'grande_loge_hg_presence_screen.dart';
import 'grande_loge_hg_session_edit_screen.dart';
import 'grande_loge_hg_session_invitations_screen.dart';

const _navyBtn = Color(0xFF0C235C);

String formatHgSessionDate(Session s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date non définie';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

int _degreeOf(Session s) => int.tryParse(s.degreTravail ?? s.degree) ?? 4;

int _chronoOf(Session s) {
  if (s.chrono != null) return s.chrono!.toInt();
  final n = int.tryParse(
    (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
  );
  return n ?? 0;
}

class GrandeLogeHgSessionDetailScreen extends StatelessWidget {
  final HgBody body;
  final Session session;
  const GrandeLogeHgSessionDetailScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditHgBody(context.watch<AppState>().currentUser, body);
    return StreamBuilder<List<Session>>(
      stream: HgBodyService.instance.sessionsStream(body),
      builder: (context, snap) {
        final current = (snap.data ?? const <Session>[]).firstWhere(
          (s) => s.id == session.id,
          orElse: () => session,
        );
        return _DetailBody(body: body, session: current, canEdit: canEdit);
      },
    );
  }
}

class _DetailBody extends StatefulWidget {
  final HgBody body;
  final Session session;
  final bool canEdit;
  const _DetailBody({
    required this.body,
    required this.session,
    required this.canEdit,
  });

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  List<Member> _members = const [];
  List<Visitor> _visitors = const [];
  List<Dignitary> _dignitaries = const [];

  @override
  void initState() {
    super.initState();
    HgBodyService.instance.membersOnce(widget.body).then((v) {
      if (mounted) setState(() => _members = v);
    });
    HgBodyService.instance.visitorsStream(widget.body).first.then((v) {
      if (mounted) setState(() => _visitors = v);
    });
    HgBodyService.instance.dignitariesStream(widget.body).first.then((v) {
      if (mounted) setState(() => _dignitaries = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final canEdit = widget.canEdit;
    final isSuspended = session.isSuspended;
    final degree = _degreeOf(session);
    final isMaaKherou = widget.body.key == kMaaKherou.key;
    final degreeName = isMaaKherou
        ? 'Maître'
        : (kIahMesDegreeNames[degree] ?? '');

    final present = _members
        .where((m) => session.presentIds.contains(m.id))
        .toList();
    final excused = _members
        .where((m) => session.excusedIds.contains(m.id))
        .toList();
    final visitors = _visitors
        .where((v) => session.visitorIds.contains(v.id))
        .toList();
    final dignitaries = _dignitaries
        .where((d) => session.dignitaryIds.contains(d.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenue — ${widget.body.label}'),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgSessionEditScreen(
                    body: widget.body,
                    session: session,
                  ),
                ),
              ),
            ),
            if (session.statut != 'Annulée')
              IconButton(
                icon: const Icon(Icons.event_busy_outlined),
                tooltip: 'Annuler la tenue',
                onPressed: () => _cancelSession(context, session),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              onPressed: () => _confirmDelete(context, session),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          BrCard(
            child: Column(
              children: [
                _infoRow('Date', formatHgSessionDate(session)),
                _infoRow('Type', session.typeLabel),
                _infoRow(
                  'Degré',
                  isMaaKherou
                      ? 'Grade de Maître'
                      : '$degree'
                            'e degré — $degreeName',
                ),
                _infoRow(
                  'Lieu',
                  (session.lieuReunionExtra ?? '').trim().isEmpty
                      ? '—'
                      : session.lieuReunionExtra!.trim(),
                ),
                _infoRow(
                  'Clôture',
                  (session.heureSuspension ?? session.closingTime).isEmpty
                      ? '—'
                      : (session.heureSuspension ?? session.closingTime),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  'Membres présents (${present.length})',
                  present.map((m) => m.fullName).toList(),
                ),
                _section(
                  'Membres excusés (${excused.length})',
                  excused.map((m) => m.fullName).toList(),
                ),
                _section(
                  'Visiteurs (${visitors.length})',
                  visitors.map((v) => '${v.fullName} — ${v.lodge}').toList(),
                ),
                _section(
                  'Dignitaires (${dignitaries.length})',
                  dignitaries
                      .map(
                        (d) => [
                          d.fullName,
                          [
                            d.title,
                            d.lodge,
                          ].where((e) => e.isNotEmpty).join(' — '),
                        ].where((e) => e.isNotEmpty).join(' — '),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const BrSectionTitle('DOCUMENTS', icon: Icons.folder_outlined),
          const SizedBox(height: 16),
          if (canEdit) ...[
            if (!isSuspended) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.violet,
                  side: const BorderSide(color: BrColors.violet),
                ),
                icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                label: const Text('Présents en tenue'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgPresenceScreen(
                      body: widget.body,
                      session: session,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.violet,
                  side: const BorderSide(color: BrColors.violet),
                ),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Invitations'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgSessionInvitationsScreen(
                      body: widget.body,
                      session: session,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.violet,
                  side: const BorderSide(color: BrColors.violet),
                ),
                icon: const Icon(Icons.campaign_outlined, size: 18),
                label: const Text('Annonce des Dignitaires'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgDignitairesAnnounceScreen(
                      body: widget.body,
                      session: session,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (isSuspended) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.gold,
                  side: const BorderSide(color: BrColors.gold),
                ),
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Modifier (déverrouillé)'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgSessionEditScreen(
                      body: widget.body,
                      session: session,
                      forceUnlock: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.gold,
                  side: const BorderSide(color: BrColors.gold),
                ),
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Présents en tenue (déverrouillé)'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgPresenceScreen(
                      body: widget.body,
                      session: session,
                      forceUnlock: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrColors.gold,
                  side: const BorderSide(color: BrColors.gold),
                ),
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Planche tracée (déverrouillée)'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrandeLogeHgPlancheScreen(
                      body: widget.body,
                      session: session,
                      forceUnlock: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: BrColors.goldBright,
                side: const BorderSide(color: BrColors.gold),
              ),
              icon: const Icon(Icons.draw_outlined, size: 18),
              label: const Text('Emargement Présence'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgEmargementScreen(
                    body: widget.body,
                    session: session,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: BrColors.gold,
                side: const BorderSide(color: BrColors.gold),
              ),
              icon: const Icon(Icons.history_edu_outlined, size: 18),
              label: const Text('Edition Planche Tracée'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GrandeLogeHgPlancheScreen(
                    body: widget.body,
                    session: session,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navyBtn),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Convocation / ordre du jour (PDF)'),
            onPressed: () => _openPdf(
              context,
              'Convocation',
              () => buildIahMesConvocationPdf(widget.body, session),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: BrColors.teal),
              icon: const Icon(Icons.people_alt_outlined, size: 18),
              label: const Text('Feuille de présence (PDF)'),
              onPressed: () => _openPdf(
                context,
                'Emargement',
                () => buildIahMesEmargementPdf(
                  widget.body,
                  session,
                  _members,
                  _visitors,
                  _dignitaries,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF701A75),
              ),
              icon: const Icon(Icons.history_edu, size: 18),
              label: const Text('Planche tracée (PDF)'),
              onPressed: () => _openPdf(
                context,
                'PlancheTracee',
                () => buildIahMesPlancheTraceePdf(
                  widget.body,
                  session,
                  _chronoOf(session),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF34D399),
                side: const BorderSide(color: Color(0xFF34D399)),
              ),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Archiver sur Google Drive'),
              onPressed: () => _archiveDrive(context, session),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _archiveDrive(BuildContext context, Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Archivage sur Google Drive...')),
    );
    try {
      final chrono = _chronoOf(session);
      final label = widget.body.label;
      final suffix = hgDriveFileSuffix(session);
      final files = <String, Uint8List>{
        'Convocation $label Tenue $chrono$suffix.pdf': Uint8List.fromList(
          await buildIahMesConvocationPdf(widget.body, session),
        ),
        'Emargement $label Tenue $chrono$suffix.pdf': Uint8List.fromList(
          await buildIahMesEmargementPdf(
            widget.body,
            session,
            _members,
            _visitors,
            _dignitaries,
          ),
        ),
        'Planche Tracee $label Tenue $chrono$suffix.pdf': Uint8List.fromList(
          await buildIahMesPlancheTraceePdf(widget.body, session, chrono),
        ),
      };
      await archiveHgSessionFiles(widget.body, session, files);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Archivé sur Google Drive.')),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Drive : $e')));
    }
  }

  Future<void> _cancelSession(BuildContext context, Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          'Annuler cette tenue ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La tenue passe au statut Annulée (elle n\'est pas supprimée). La '
          'modifier ensuite la reprogrammera automatiquement.',
          style: TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler la tenue'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final map = session.toMap();
    map['status'] = 'Annulée';
    await HgBodyService.instance.updateSession(
      widget.body,
      Session.fromMap(session.id, map),
    );
    messenger.showSnackBar(const SnackBar(content: Text('Tenue annulée.')));
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          'Supprimer la tenue ?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Cette action est définitive.',
          style: TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HgBodyService.instance.deleteSession(widget.body, session.id);
      navigator.pop();
    }
  }

  Future<void> _openPdf(
    BuildContext context,
    String prefix,
    Future<List<int>> Function() builder,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await builder();
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: '${prefix}_tenue.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: BrColors.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: BrColors.text)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text(
              'Néant',
              style: TextStyle(color: BrColors.muted, fontSize: 13),
            )
          else
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '• $e',
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
