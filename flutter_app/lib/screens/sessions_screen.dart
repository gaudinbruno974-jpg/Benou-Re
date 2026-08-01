// Liste des tenues (porté partiellement depuis src/components/SessionsList.tsx).
// Lecture + détail. La génération de planche/PDF/Drive reste à porter (voir README).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'emargement_screen.dart';
import 'session_edit_screen.dart';
import 'session_presence_screen.dart';

const _navyBtn = Color(0xFF0C235C);

String formatSessionDate(Session s) {
  final dt = s.dateTime;
  if (dt == null) return 'Date inconnue';
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sessions = state.sessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenues')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: BrColors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle tenue'),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SessionEditScreen())),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'Aucune tenue planifiée',
                style: TextStyle(color: BrColors.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SessionCard(session: sessions[i]),
            ),
    );
  }
}

String _timeOf(Session s) {
  final dt = s.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) return '';
  return DateFormat('HH:mm').format(dt);
}

class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final ord = Session.degreeOrdinal(s.degreeLabel);
    final points = 4 + s.ordresJourCount + 1;
    final heure = _timeOf(s);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SessionDetailScreen(session: s)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _badge(
                    s.typeLabel,
                    s.typeLabel == 'Banquet' ? BrColors.gold : BrColors.teal,
                  ),
                  _badge('${s.degreeLabel} ($ord Degré)', BrColors.gold),
                  _badge(s.statut, _statusColor(s.statut)),
                  if (s.chrono != null)
                    _badge('Tenue n°${s.chrono!.toInt()}', BrColors.gold),
                  if ((s.driveFolderUrl ?? '').isNotEmpty)
                    _badge('Drive', BrColors.teal, icon: Icons.folder_open),
                  if (s.isValidated)
                    _badge(
                      'Validée',
                      const Color(0xFF34D399),
                      icon: Icons.verified,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _capitalize(formatSessionDate(s)),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (heure.isNotEmpty)
                    _iconText(
                      Icons.schedule,
                      (s.heureSuspension ?? '').isNotEmpty
                          ? '$heure → ${s.heureSuspension}'
                          : heure,
                    ),
                  _iconText(
                    Icons.place_outlined,
                    s.location.isNotEmpty ? s.location : '—',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(left: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: BrColors.gold, width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDRE DU JOUR ($points points)',
                      style: const TextStyle(
                        color: BrColors.muted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _agendaSummary(s),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (s.suitAgapes && (s.typeRepas ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                _iconText(
                  Icons.restaurant,
                  (s.montantMedaille ?? 0) > 0
                      ? '${s.typeRepas} — ${s.montantMedaille} €'
                      : s.typeRepas!,
                  color: BrColors.gold,
                ),
              ],
              const Divider(height: 20, color: BrColors.gold),
              Row(
                children: [
                  _action(
                    context,
                    Icons.groups_outlined,
                    'Émargement',
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmargementScreen(sessionId: s.id),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Modifier',
                    icon: const Icon(
                      Icons.edit,
                      size: 20,
                      color: BrColors.muted,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionEditScreen(session: s),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Détail & documents',
                    icon: const Icon(
                      Icons.chevron_right,
                      color: BrColors.muted,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(session: s),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _agendaSummary(Session s) {
    final parts = [
      if ((s.travail1 ?? '').isNotEmpty) '1. ${s.travail1}',
      if ((s.travail2 ?? '').isNotEmpty) '2. ${s.travail2}',
      if ((s.travail3 ?? '').isNotEmpty) '3. ${s.travail3}',
      if ((s.travail4 ?? '').isNotEmpty) '4. ${s.travail4}',
    ];
    var text = parts.join(' — ');
    if (s.ordresJourCount > 0) text += ' — +${s.ordresJourCount} ordre(s)';
    if ((s.ligneCloture ?? '').isNotEmpty) text += ' — ${s.ligneCloture}';
    return text.isEmpty ? 'Ordre du jour non renseigné' : text;
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Terminée':
        return const Color(0xFF34D399);
      case 'Annulée':
        return Colors.redAccent;
      default:
        return const Color(0xFF60A5FA);
    }
  }

  Widget _badge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? BrColors.teal),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color ?? BrColors.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF34D399),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Toujours refléter la dernière version en base (après édition/signature).
    final session = state.sessions.firstWhere(
      (s) => s.id == this.session.id,
      orElse: () => this.session,
    );
    final present = state.members
        .where((m) => session.presentIds.contains(m.id))
        .toList();
    final excused = state.members
        .where((m) => session.excusedIds.contains(m.id))
        .toList();
    final visitors = state.visitors
        .where((v) => session.visitorIds.contains(v.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title.isNotEmpty ? session.title : 'Tenue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionEditScreen(session: session),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context, state, session),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoRow('Date', formatSessionDate(session)),
          _infoRow('Type', session.type),
          _infoRow('Degré', session.degree),
          _infoRow(
            'Lieu',
            session.location.isNotEmpty ? session.location : '—',
          ),
          _infoRow('Tronc de la Veuve', '${session.troncAmount} €'),
          _infoRow('Clôture', session.closingTime),
          const SizedBox(height: 16),
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
          const SizedBox(height: 20),
          const Text(
            'DOCUMENTS',
            style: TextStyle(
              color: BrColors.gold,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BrColors.violet,
              side: const BorderSide(color: BrColors.violet),
            ),
            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
            label: const Text('Présence'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SessionPresenceScreen(sessionId: session.id),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BrColors.goldBright,
              side: const BorderSide(color: BrColors.gold),
            ),
            icon: const Icon(Icons.draw_outlined, size: 18),
            label: const Text('Émargement / signatures'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmargementScreen(sessionId: session.id),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: BrColors.teal),
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: const Text("Feuille de présence (PDF)"),
            onPressed: () => _openPdf(
              context,
              'Emargement',
              () => buildEmargementPdf(session, state.members, state.visitors),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navyBtn),
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Convocation / ordre du jour (PDF)'),
            onPressed: () => _openPdf(
              context,
              'Convocation',
              () => buildConvocationPdf(session, _chrono(session)),
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
              () => buildPlancheTraceePdf(
                session,
                state.members,
                state.visitors,
                _chrono(session),
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
            onPressed: () => _archiveDrive(context, session, state),
          ),
          const SizedBox(height: 12),
          const Text(
            "L'archivage envoie les 3 PDF dans le dossier « Tenue … » sur Google Drive. Nécessite la connexion Google (voir README pour la config OAuth).",
            style: TextStyle(color: BrColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveDrive(
    BuildContext context,
    Session session,
    AppState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Connexion Google et archivage en cours...'),
      ),
    );
    try {
      final chrono = _chrono(session);
      final files = <String, Uint8List>{
        'Convocation_Tenue_$chrono.pdf': Uint8List.fromList(
          await buildConvocationPdf(session, chrono),
        ),
        'Emargement_Tenue_$chrono.pdf': Uint8List.fromList(
          await buildEmargementPdf(session, state.members, state.visitors),
        ),
        'PlancheTracee_Tenue_$chrono.pdf': Uint8List.fromList(
          await buildPlancheTraceePdf(
            session,
            state.members,
            state.visitors,
            chrono,
          ),
        ),
      };
      final email = await DriveService.instance.archivePdfs(session, files);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Archivé sur Google Drive ($email).')),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Drive : $e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState state,
    Session session,
  ) async {
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
      await state.deleteSession(session.id);
      navigator.pop();
    }
  }

  int _chrono(Session s) {
    if (s.chrono != null) return s.chrono!.toInt();
    final n = int.tryParse(
      (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
    );
    return n ?? 0;
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
