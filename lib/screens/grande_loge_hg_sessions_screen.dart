// Liste des tenues d'un corps de Hauts Grades — même principe que
// sessions_screen.dart (loges bleues) : onglets Reprise des Travaux /
// Travaux Suspendus, cartes riches (badges, résumé de l'ordre du jour,
// action rapide Emargement), navigation vers la fiche détail.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart' show kIahMesDegreeNames;
import '../models/session.dart';
import '../services/hg_body_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'grande_loge_hg_emargement_screen.dart';
import 'grande_loge_hg_session_detail_screen.dart';
import 'grande_loge_hg_session_edit_screen.dart';

int _degreeOf(Session s) => int.tryParse(s.degreTravail ?? s.degree) ?? 4;

String _timeOf(Session s) {
  final dt = s.dateTime;
  if (dt == null || (dt.hour == 0 && dt.minute == 0)) return '';
  return DateFormat('HH:mm').format(dt);
}

class GrandeLogeHgSessionsScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgSessionsScreen({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    final canEdit = canEditHgBody(context.watch<AppState>().currentUser, body);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Tenues — ${body.label}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reprise des Travaux'),
              Tab(text: 'Travaux Suspendus'),
            ],
          ),
        ),
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
        body: StreamBuilder<List<Session>>(
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
            final upcoming = <Session>[];
            final past = <Session>[];
            for (final s in sessions) {
              (s.isSuspended ? past : upcoming).add(s);
            }
            return TabBarView(
              children: [
                _SessionsList(
                  body: body,
                  sessions: upcoming,
                  canEdit: canEdit,
                  emptyMessage: 'Aucune tenue à venir',
                ),
                _SessionsList(
                  body: body,
                  sessions: past,
                  canEdit: canEdit,
                  emptyMessage: 'Aucune tenue suspendue',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionsList extends StatelessWidget {
  final HgBody body;
  final List<Session> sessions;
  final bool canEdit;
  final String emptyMessage;
  const _SessionsList({
    required this.body,
    required this.sessions,
    required this.canEdit,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: BrColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, i) =>
          _SessionCard(body: body, session: sessions[i], canEdit: canEdit),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final HgBody body;
  final Session session;
  final bool canEdit;
  const _SessionCard({
    required this.body,
    required this.session,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final s = session;
    final isMaaKherou = body.key == kMaaKherou.key;
    final degree = _degreeOf(s);
    final degreeName = isMaaKherou
        ? 'Maître'
        : (kIahMesDegreeNames[degree] ?? '');
    final points = 4 + s.ordresJourCount + 1;
    final heure = _timeOf(s);

    return BrCard(
      accent: _statusColor(s.statut),
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GrandeLogeHgSessionDetailScreen(body: body, session: s),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(
                s.typeLabel,
                s.typeLabel == 'Banquet' ? BrColors.gold : BrColors.teal,
              ),
              _badge(
                isMaaKherou
                    ? 'Grade de Maître'
                    : '$degree'
                          'e degré — $degreeName',
                BrColors.gold,
              ),
              _badge(s.statut, _statusColor(s.statut)),
              if (s.chrono != null)
                _badge('Tenue n°${s.chrono!.toInt()}', BrColors.gold),
              if (s.isValidated)
                _badge(
                  'Validée',
                  const Color(0xFF34D399),
                  icon: Icons.verified,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.chrono != null && s.dateTime != null
                ? 'Tenue n°${s.chrono!.toInt()} — ${DateFormat('d MMM y', 'fr_FR').format(s.dateTime!)}'
                : _capitalize(_formatDate(s)),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16.5,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
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
                (s.lieuReunionExtra ?? '').trim().isNotEmpty
                    ? s.lieuReunionExtra!.trim()
                    : '—',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: BrColors.backgroundDark.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(BrColors.radiusS),
              border: const Border(
                left: BorderSide(color: BrColors.gold, width: 3),
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
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
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
          Divider(height: 26, color: BrColors.gold.withValues(alpha: 0.35)),
          Row(
            children: [
              if (canEdit)
                _action(
                  context,
                  Icons.groups_outlined,
                  'Emargement',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GrandeLogeHgEmargementScreen(body: body, session: s),
                    ),
                  ),
                ),
              const Spacer(),
              if (canEdit)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit, size: 20, color: BrColors.muted),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          GrandeLogeHgSessionEditScreen(body: body, session: s),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Détail & documents',
                icon: const Icon(Icons.chevron_right, color: BrColors.muted),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GrandeLogeHgSessionDetailScreen(body: body, session: s),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(Session s) {
    final dt = s.dateTime;
    if (dt == null) return 'Date non définie';
    return DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
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
    return BrBadge(label: text, color: color, icon: icon);
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
