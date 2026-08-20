// Invitations d'une Tenue planifiée : un lien de réponse individuel par
// destinataire — « Convocation Bénou-Ré » pour les membres de la Loge (Flux
// A, réponse nominative Présent/Absent/Agapes), « Invitation » pour les
// dignitaires et Vénérables d'autres Loges (Flux B, décompte de délégation
// par grade). Chaque lien porte son propre texte complet (convocation ou
// invitation, mandatement compris), le lien de réponse étant propre au
// destinataire — voir invitation_service.dart pour la composition des
// textes. La convocation PDF se joint via le partage système.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/preferred_contact.dart';
import '../models/presence_link.dart';
import '../models/session.dart';
import '../services/invitation_service.dart';
import '../services/pdf_service.dart';
import '../services/url_opener.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

/// Lien d'envoi d'un e-mail. `mailto:` ne fonctionne que si le navigateur a
/// un client mail natif associé (souvent absent chez les utilisateurs
/// Gmail/webmail sur ordinateur) : sur le web on ouvre donc directement la
/// fenêtre de composition Gmail, qui n'a pas ce prérequis. Sur mobile,
/// `mailto:` déclenche normalement le choix de l'app mail installée.
String _emailUrl({
  required String to,
  required String subject,
  required String body,
}) {
  if (kIsWeb) {
    return 'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=${Uri.encodeComponent(to)}'
        '&su=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}';
  }
  return 'mailto:$to'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}';
}

class SessionInvitationsScreen extends StatefulWidget {
  final String sessionId;
  const SessionInvitationsScreen({super.key, required this.sessionId});

  @override
  State<SessionInvitationsScreen> createState() =>
      _SessionInvitationsScreenState();
}

class _SessionInvitationsScreenState extends State<SessionInvitationsScreen> {
  bool _presenceLinksEnabled = false;
  bool _delegationLinksEnabled = false;

  int _chrono(Session s) {
    if (s.chrono != null) return s.chrono!.toInt();
    return int.tryParse(
          (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
        ) ??
        0;
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texte copié.'),
        backgroundColor: BrColors.teal,
      ),
    );
  }

  Future<void> _open(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await openExternalUrl(url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Ouverture : $e')));
    }
  }

  Future<void> _shareConvocation(Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    try {
      final bytes = await buildConvocationPdf(
        session,
        _chrono(session),
        state.members,
        lodgeVmName: state.lodgeVmName,
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'Convocation_Tenue_${_chrono(session)}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => Session(id: widget.sessionId),
    );
    final chrono = _chrono(session);

    return Scaffold(
      appBar: AppBar(title: Text('Invitations — Tenue $chrono')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: BrColors.goldBright,
              side: const BorderSide(color: BrColors.gold),
            ),
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Joindre la convocation (PDF)'),
            onPressed: () => _shareConvocation(session),
          ),
          const SizedBox(height: 18),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _presenceLinksEnabled,
                  onChanged: (v) =>
                      setState(() => _presenceLinksEnabled = v ?? false),
                  title: Text(
                    'Convocation ${LodgeConfig.current.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Chaque membre reçoit un lien personnel : il répond '
                    'Présent/Absent (et Agapes) sans se connecter à '
                    'l\'application.',
                    style: TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ),
                if (_presenceLinksEnabled)
                  _PresenceLinksSection(
                    session: session,
                    chrono: chrono,
                    onCopy: _copy,
                    onOpen: _open,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _delegationLinksEnabled,
                  onChanged: (v) =>
                      setState(() => _delegationLinksEnabled = v ?? false),
                  title: const Text(
                    'Invitation',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Chaque dignitaire ou Vénérable invité reçoit un lien '
                    'pour déclarer le nombre de personnes de sa délégation '
                    'présentes, par grade, sans se connecter.',
                    style: TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ),
                if (_delegationLinksEnabled)
                  _DelegationLinksSection(
                    session: session,
                    chrono: chrono,
                    onCopy: _copy,
                    onOpen: _open,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section « Convocation Bénou-Ré » : un lien par membre éligible à cette
/// tenue (même filtrage par degré que l'écran Présences), généré une fois
/// puis stable — voir presence_link.dart et AppState pour la synchronisation
/// automatique des réponses reçues.
class _PresenceLinksSection extends StatefulWidget {
  final Session session;
  final int chrono;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _PresenceLinksSection({
    required this.session,
    required this.chrono,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  State<_PresenceLinksSection> createState() => _PresenceLinksSectionState();
}

class _PresenceLinksSectionState extends State<_PresenceLinksSection> {
  bool _generating = false;

  // Pas de recherche/bascule Par Loge ici : contrairement aux Visiteurs et
  // Dignitaires, les membres appartiennent tous à la Loge courante — même
  // exclusion que le panneau Membres de « Présents en tenue ».
  List<Member> _eligibleMembers(AppState state) {
    final rank = Session.degreeRank(widget.session.degreeLabel);
    final members = state.members
        .where((m) => Session.degreeRank(m.grade) >= rank)
        .toList()
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    return members;
  }

  String _linkUrl(String token) =>
      '${LodgeConfig.current.webOrigin}/#/reponse/$token';

  Future<void> _generateMissing(
    List<Member> eligible,
    List<PresenceLink> existing,
  ) async {
    final dt = widget.session.dateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La tenue doit avoir une date pour générer les liens.',
          ),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    final state = context.read<AppState>();
    final expiresAt = DateTime(dt.year, dt.month, dt.day);
    final existingMemberIds = existing.map((l) => l.memberId).toSet();
    final sessionLabel = invitationTitle(widget.session, widget.chrono);
    final sessionDateLabel = DateFormat(
      'EEEE d MMMM y',
      'fr_FR',
    ).format(dt);
    for (final m in eligible) {
      if (existingMemberIds.contains(m.id)) continue;
      await state.createPresenceLink(
        PresenceLink(
          id: generatePresenceToken(),
          sessionId: widget.session.id,
          memberId: m.id,
          memberName: m.fullName,
          sessionLabel: sessionLabel,
          sessionDateLabel: sessionDateLabel,
          sessionType: widget.session.typeLabel,
          sessionDegreeLabel: Session.degreeOrdinal(
            widget.session.degreeLabel,
          ),
          hasAgape: widget.session.suitAgapes,
          expiresAt: expiresAt,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final eligible = _eligibleMembers(state);
    final ordreDuJour = plancheOrdreDuJour(widget.session);

    return StreamBuilder<List<PresenceLink>>(
      stream: state.presenceLinksForSession(widget.session.id),
      builder: (context, snapshot) {
        final existing = snapshot.data ?? const <PresenceLink>[];
        final byMember = {for (final l in existing) l.memberId: l};
        final missing = eligible
            .where((m) => !byMember.containsKey(m.id))
            .length;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    icon: _generating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link, size: 16),
                    label: Text('Générer les liens ($missing manquant(s))'),
                    onPressed: _generating
                        ? null
                        : () => _generateMissing(eligible, existing),
                  ),
                ),
              for (final m in eligible)
                _PresenceLinkRow(
                  session: widget.session,
                  chrono: widget.chrono,
                  ordreDuJour: ordreDuJour,
                  allMembers: state.members,
                  lodgeVmName: state.lodgeVmName,
                  member: m,
                  link: byMember[m.id],
                  linkUrl: byMember[m.id] != null
                      ? _linkUrl(byMember[m.id]!.id)
                      : null,
                  onCopy: widget.onCopy,
                  onOpen: widget.onOpen,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PresenceLinkRow extends StatelessWidget {
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final List<Member> allMembers;
  final String lodgeVmName;
  final Member member;
  final PresenceLink? link;
  final String? linkUrl;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _PresenceLinkRow({
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.allMembers,
    required this.lodgeVmName,
    required this.member,
    required this.link,
    required this.linkUrl,
    required this.onCopy,
    required this.onOpen,
  });

  Color get _statusColor {
    switch (link?.status) {
      case kPresenceStatusPresent:
        return BrColors.menuVisiteurs;
      case kPresenceStatusAbsent:
        return BrColors.menuTresorerie;
      default:
        return BrColors.muted;
    }
  }

  String get _statusLabel {
    switch (link?.status) {
      case kPresenceStatusPresent:
        return 'Présent'
            '${link?.agapePresent == true ? ' + agapes' : ''}';
      case kPresenceStatusAbsent:
        return 'Absent';
      default:
        return link == null ? 'Lien non généré' : 'En attente';
    }
  }

  String _digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

  @override
  Widget build(BuildContext context) {
    final url = linkUrl;
    final message = url == null
        ? ''
        : memberConvocationBody(
            session,
            ordreDuJour,
            allMembers,
            url,
            lodgeVmName: lodgeVmName,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                ),
                Text(
                  _statusLabel,
                  style: TextStyle(color: _statusColor, fontSize: 11),
                ),
              ],
            ),
          ),
          if (url != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copier le texte',
              icon: const Icon(Icons.copy, size: 18, color: BrColors.muted),
              onPressed: () => onCopy(message),
            ),
            if (member.phone.trim().isNotEmpty)
              _ChannelButton(
                icon: Icons.chat_outlined,
                color: BrColors.teal,
                tooltip: 'Envoyer sur WhatsApp',
                preferred: member.preferredContact == kContactWhatsApp,
                onPressed: () => onOpen(
                  'https://wa.me/${_digitsOnly(member.phone)}'
                  '?text=${Uri.encodeComponent(message)}',
                ),
              ),
            if (member.email.trim().isNotEmpty)
              _ChannelButton(
                icon: Icons.mail_outline,
                color: BrColors.violet,
                tooltip: 'Envoyer par e-mail',
                preferred: member.preferredContact == kContactCourriel,
                onPressed: () => onOpen(
                  _emailUrl(
                    to: member.email.trim(),
                    subject: memberConvocationSubject(session, chrono),
                    body: message,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Section « Invitation » (Flux B) : un lien par dignitaire ou Vénérable
/// d'une autre Loge — même collection `dignitaries` que les visiteurs
/// annoncés — avec la synthèse des réponses reçues.
class _DelegationLinksSection extends StatefulWidget {
  final Session session;
  final int chrono;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _DelegationLinksSection({
    required this.session,
    required this.chrono,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  State<_DelegationLinksSection> createState() =>
      _DelegationLinksSectionState();
}

class _DelegationLinksSectionState extends State<_DelegationLinksSection> {
  bool _generating = false;
  final _search = TextEditingController();
  DirectoryGroupMode _mode = DirectoryGroupMode.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _linkUrl(String token) =>
      '${LodgeConfig.current.webOrigin}/#/reponse/$token';

  List<Widget> _delegationList(
    List<Dignitary> visible,
    Widget Function(Dignitary) row,
  ) {
    if (visible.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Aucun résultat.', style: TextStyle(color: BrColors.muted)),
        ),
      ];
    }
    if (_mode == DirectoryGroupMode.all) {
      return [for (final d in visible) row(d)];
    }
    final groups = groupDirectory(
      visible,
      (d) => _mode == DirectoryGroupMode.byLodge ? d.lodge : d.obedience,
    );
    return [
      for (final g in groups)
        DirectoryGroupSection(
          title: g.key,
          count: g.value.length,
          initiallyExpanded: groups.length == 1,
          children: [for (final d in g.value) row(d)],
        ),
    ];
  }

  Future<void> _generateMissing(
    List<Dignitary> recipients,
    List<PresenceLink> existing,
  ) async {
    final dt = widget.session.dateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La tenue doit avoir une date pour générer les liens.',
          ),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    final state = context.read<AppState>();
    final expiresAt = DateTime(dt.year, dt.month, dt.day);
    final existingRecipientIds = existing.map((l) => l.recipientId).toSet();
    final sessionLabel = invitationTitle(widget.session, widget.chrono);
    final sessionDateLabel = DateFormat('EEEE d MMMM y', 'fr_FR').format(dt);
    for (final d in recipients) {
      if (existingRecipientIds.contains(d.id)) continue;
      await state.createPresenceLink(
        PresenceLink(
          id: generatePresenceToken(),
          kind: kPresenceLinkKindDelegation,
          sessionId: widget.session.id,
          sessionLabel: sessionLabel,
          sessionDateLabel: sessionDateLabel,
          sessionType: widget.session.typeLabel,
          sessionDegreeLabel: Session.degreeOrdinal(
            widget.session.degreeLabel,
          ),
          hasAgape: widget.session.suitAgapes,
          recipientId: d.id,
          recipientName: d.fullName,
          expiresAt: expiresAt,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Tout dignitaire joignable (e-mail ou téléphone) peut être destinataire
    // d'un lien : le bureau choisit ensuite, ligne par ligne, à qui l'envoyer.
    final recipients = state.dignitaries
        .where((d) => d.email.trim().isNotEmpty || d.phone.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    final ordreDuJour = plancheOrdreDuJour(widget.session);

    return StreamBuilder<List<PresenceLink>>(
      stream: state.presenceLinksForSession(widget.session.id),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <PresenceLink>[];
        final existing = all
            .where((l) => l.kind == kPresenceLinkKindDelegation)
            .toList();
        final byRecipient = {for (final l in existing) l.recipientId: l};
        final missing = recipients
            .where((d) => !byRecipient.containsKey(d.id))
            .length;
        final answered = existing.where((l) => l.isAnswered).toList();
        final totalApprenti = answered.fold<int>(
          0,
          (sum, l) => sum + (l.apprentiCount ?? 0),
        );
        final totalCompagnon = answered.fold<int>(
          0,
          (sum, l) => sum + (l.compagnonCount ?? 0),
        );
        final totalMaitre = answered.fold<int>(
          0,
          (sum, l) => sum + (l.maitreCount ?? 0),
        );
        final totalAgapes = answered.fold<int>(
          0,
          (sum, l) => sum + (l.agapeTotal ?? 0),
        );
        final visible =
            recipients
                .where(
                  (d) => directoryMatches(_search.text, [
                    d.firstName,
                    d.lastName,
                    d.lodge,
                    d.obedience,
                  ]),
                )
                .toList()
              ..sort((a, b) => directoryCompare(a.lastName, b.lastName));

        Widget row(Dignitary d) => _DelegationLinkRow(
          session: widget.session,
          chrono: widget.chrono,
          ordreDuJour: ordreDuJour,
          allMembers: state.members,
          lodgeVmName: state.lodgeVmName,
          dignitary: d,
          link: byRecipient[d.id],
          linkUrl: byRecipient[d.id] != null
              ? _linkUrl(byRecipient[d.id]!.id)
              : null,
          onCopy: widget.onCopy,
          onOpen: widget.onOpen,
        );

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missing > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    icon: _generating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link, size: 16),
                    label: Text('Générer les liens ($missing manquant(s))'),
                    onPressed: _generating
                        ? null
                        : () => _generateMissing(recipients, existing),
                  ),
                ),
              if (answered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BrBadge(
                        label: '$totalApprenti Apprenti(s)',
                        color: BrColors.menuArchitecture,
                      ),
                      BrBadge(
                        label: '$totalCompagnon Compagnon(s)',
                        color: BrColors.menuVisiteurs,
                      ),
                      BrBadge(
                        label: '$totalMaitre Maître(s)',
                        color: BrColors.gold,
                      ),
                      BrBadge(
                        label: '$totalAgapes agapes',
                        color: BrColors.teal,
                      ),
                    ],
                  ),
                ),
              if (recipients.length > 1) ...[
                DirectoryFilterBar(
                  controller: _search,
                  mode: _mode,
                  onModeChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 10),
              ],
              ..._delegationList(visible, row),
            ],
          ),
        );
      },
    );
  }
}

/// Bouton d'envoi (WhatsApp / e-mail) d'une ligne de lien, mis en évidence
/// par un liseré quand ce canal est le « Canal préféré » de la fiche —
/// l'autre bouton reste cliquable, ce n'est qu'un repère visuel.
class _ChannelButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool preferred;
  final VoidCallback onPressed;
  const _ChannelButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.preferred,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: preferred ? '$tooltip (préféré)' : tooltip,
      icon: Icon(icon, size: 18, color: color),
      onPressed: onPressed,
    );
    if (!preferred) return button;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: button,
    );
  }
}

class _DelegationLinkRow extends StatelessWidget {
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final List<Member> allMembers;
  final String lodgeVmName;
  final Dignitary dignitary;
  final PresenceLink? link;
  final String? linkUrl;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _DelegationLinkRow({
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.allMembers,
    required this.lodgeVmName,
    required this.dignitary,
    required this.link,
    required this.linkUrl,
    required this.onCopy,
    required this.onOpen,
  });

  String get _statusLabel {
    final l = link;
    if (l == null) return 'Lien non généré';
    if (!l.isAnswered) return 'En attente';
    return '${l.apprentiCount ?? 0}A · ${l.compagnonCount ?? 0}C · '
        '${l.maitreCount ?? 0}M · ${l.agapeTotal ?? 0} agapes';
  }

  Color get _statusColor {
    final l = link;
    if (l == null || !l.isAnswered) return BrColors.muted;
    return BrColors.menuVisiteurs;
  }

  String _digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

  @override
  Widget build(BuildContext context) {
    final url = linkUrl;
    final message = url == null
        ? ''
        : dignitaryInvitationBody(
            session,
            ordreDuJour,
            allMembers,
            url,
            lodgeVmName: lodgeVmName,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dignitary.fullName,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                ),
                Text(
                  _statusLabel,
                  style: TextStyle(color: _statusColor, fontSize: 11),
                ),
              ],
            ),
          ),
          if (url != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Copier le texte',
              icon: const Icon(Icons.copy, size: 18, color: BrColors.muted),
              onPressed: () => onCopy(message),
            ),
            if (dignitary.phone.trim().isNotEmpty)
              _ChannelButton(
                icon: Icons.chat_outlined,
                color: BrColors.teal,
                tooltip: 'Envoyer sur WhatsApp',
                preferred: dignitary.preferredContact == kContactWhatsApp,
                onPressed: () => onOpen(
                  'https://wa.me/${_digitsOnly(dignitary.phone)}'
                  '?text=${Uri.encodeComponent(message)}',
                ),
              ),
            if (dignitary.email.trim().isNotEmpty)
              _ChannelButton(
                icon: Icons.mail_outline,
                color: BrColors.violet,
                tooltip: 'Envoyer par e-mail',
                preferred: dignitary.preferredContact == kContactCourriel,
                onPressed: () => onOpen(
                  _emailUrl(
                    to: dignitary.email.trim(),
                    subject: dignitaryInvitationSubject(session, chrono),
                    body: message,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
