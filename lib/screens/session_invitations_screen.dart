// Invitations d'une Tenue planifiée : trois destinations (groupe WhatsApp de la
// Loge, groupe WhatsApp de l'Obédience, invités par e-mail).
//
// L'API WhatsApp ne permet ni les sondages ni l'envoi dans un groupe : l'app
// prépare le texte et ouvre WhatsApp (choix du groupe par l'utilisateur) ou le
// client mail. La convocation PDF se joint via le partage système.

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

class SessionInvitationsScreen extends StatefulWidget {
  final String sessionId;
  const SessionInvitationsScreen({super.key, required this.sessionId});

  @override
  State<SessionInvitationsScreen> createState() =>
      _SessionInvitationsScreenState();
}

/// Visiteur ou dignitaire ayant un e-mail : unifiés pour la liste des
/// destinataires de l'invitation par e-mail.
class _Guest {
  final String id;
  final String fullName;
  final String email;
  final String lodge;
  final String obedience;
  const _Guest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.lodge,
    required this.obedience,
  });
}

class _SessionInvitationsScreenState extends State<SessionInvitationsScreen> {
  final _selectedGuests = <String>{};
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
    final ordreDuJour = plancheOrdreDuJour(session);
    // Seuls les dignitaires sont invités directement par e-mail : dans la
    // logique maçonnique, ce sont eux qui invitent ensuite les membres de
    // leur propre loge, pas l'application qui contacte des visiteurs isolés.
    final guests = <_Guest>[
      for (final d in state.dignitaries)
        if (d.email.trim().isNotEmpty)
          _Guest(
            id: d.id,
            fullName: d.fullName,
            email: d.email.trim(),
            lodge: d.lodge,
            obedience: d.obedience,
          ),
    ];
    // Décochés par défaut : l'expéditeur choisit qui reçoit le mail.

    final lodgeText = lodgeInvitationText(session, chrono, ordreDuJour);
    final obedienceText = obedienceInvitationText(
      session,
      state.members,
      chrono,
    );
    final emailText = emailInvitationText(session, chrono, ordreDuJour);
    final recipients = guests
        .where((g) => _selectedGuests.contains(g.id))
        .map((g) => g.email)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Invitations — Tenue $chrono')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          const Text(
            'WhatsApp ne permet pas de créer un sondage ni d\'écrire dans un '
            'groupe depuis une application : le texte est préparé ici, le '
            'groupe se choisit dans WhatsApp.',
            style: TextStyle(color: BrColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          _InvitationCard(
            title: 'GROUPE LOGE',
            text: lodgeText,
            onWhatsApp: () => _open(whatsappShareUrl(lodgeText)),
            onCopy: () => _copy(lodgeText),
          ),
          const SizedBox(height: 18),
          _InvitationCard(
            title: 'GROUPE OBÉDIENCE',
            text: obedienceText,
            onWhatsApp: () => _open(whatsappShareUrl(obedienceText)),
            onCopy: () => _copy(obedienceText),
          ),
          const SizedBox(height: 18),
          _InvitationCard(
            title: 'INVITÉS PAR E-MAIL',
            text: emailText,
            onCopy: () => _copy(emailText),
            onEmail: recipients.isEmpty
                ? null
                : () => _open(
                      mailtoUrl(
                        recipients: recipients,
                        subject: invitationTitle(session, chrono),
                        body: emailText,
                      ),
                    ),
            guests: guests,
            selectedGuests: _selectedGuests,
            onGuestToggle: (id) => setState(
              () => _selectedGuests.contains(id)
                  ? _selectedGuests.remove(id)
                  : _selectedGuests.add(id),
            ),
          ),
          const SizedBox(height: 18),
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
                  title: const Text(
                    'Liens de réponse individuels (test — Bénou Ré)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
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
                    'Décompte de délégation (test — Bénou Ré)',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Chaque dignitaire ou Vénérable invité (Loge/obédience '
                    'extérieure) reçoit un lien pour déclarer le nombre de '
                    'personnes de sa délégation présentes, par grade, sans '
                    'se connecter.',
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

/// Section « Liens de réponse individuels » : un lien par membre éligible à
/// cette tenue (même filtrage par degré que l'écran Présences), généré une
/// fois puis stable — voir presence_link.dart et AppState pour la
/// synchronisation automatique des réponses reçues.
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
  final Member member;
  final PresenceLink? link;
  final String? linkUrl;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _PresenceLinkRow({
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
        : 'Bonjour ${member.firstName}, merci de confirmer votre présence '
              'à la prochaine tenue via ce lien : $url';
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
              tooltip: 'Copier le lien',
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
                  'mailto:${member.email.trim()}'
                  '?subject=${Uri.encodeComponent('Confirmation de présence')}'
                  '&body=${Uri.encodeComponent(message)}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InvitationCard extends StatefulWidget {
  final String title;
  final String text;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onEmail;
  final VoidCallback onCopy;
  final List<_Guest> guests;
  final Set<String> selectedGuests;
  final ValueChanged<String>? onGuestToggle;

  const _InvitationCard({
    required this.title,
    required this.text,
    required this.onCopy,
    this.onWhatsApp,
    this.onEmail,
    this.guests = const [],
    this.selectedGuests = const {},
    this.onGuestToggle,
  });

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
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

  Widget _guestTile(_Guest g) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: widget.selectedGuests.contains(g.id),
      onChanged: widget.onGuestToggle == null
          ? null
          : (_) => widget.onGuestToggle!(g.id),
      title: Text(
        g.fullName,
        style: const TextStyle(color: BrColors.text, fontSize: 13),
      ),
      subtitle: Text(
        [g.email, g.lodge].where((e) => e.isNotEmpty).join(' — '),
        style: const TextStyle(color: BrColors.muted, fontSize: 11),
      ),
    );
  }

  Widget _guestList() {
    final filtered =
        widget.guests
            .where(
              (g) => directoryMatches(_search.text, [
                g.fullName,
                g.lodge,
                g.obedience,
              ]),
            )
            .toList()
          ..sort((a, b) => directoryCompare(a.fullName, b.fullName));
    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Aucun résultat.', style: TextStyle(color: BrColors.muted)),
      );
    }
    if (_mode == DirectoryGroupMode.all) {
      return Column(children: [for (final g in filtered) _guestTile(g)]);
    }
    final groups = groupDirectory(
      filtered,
      (g) => _mode == DirectoryGroupMode.byLodge ? g.lodge : g.obedience,
    );
    return Column(
      children: [
        for (final grp in groups)
          DirectoryGroupSection(
            title: grp.key,
            count: grp.value.length,
            initiallyExpanded: groups.length == 1,
            children: [for (final g in grp.value) _guestTile(g)],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrSectionTitle(widget.title, icon: Icons.send_outlined),
          const SizedBox(height: 10),
          SelectableText(
            widget.text,
            style: const TextStyle(color: BrColors.text, fontSize: 13),
          ),
          if (widget.guests.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Destinataires',
              style: TextStyle(color: BrColors.gold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            DirectoryFilterBar(
              controller: _search,
              mode: _mode,
              onModeChanged: (m) => setState(() => _mode = m),
              hintText: 'Rechercher un dignitaire, une Loge, une Obédience…',
            ),
            const SizedBox(height: 8),
            _guestList(),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (widget.onWhatsApp != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrColors.teal,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Envoyer sur WhatsApp'),
                  onPressed: widget.onWhatsApp,
                ),
              if (widget.onEmail != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrColors.violet,
                  ),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Envoyer par e-mail'),
                  onPressed: widget.onEmail,
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier'),
                onPressed: widget.onCopy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section « Décompte de délégation » (Flux B) : un lien par dignitaire ou
/// Vénérable d'une autre Loge — même collection `dignitaries` que les
/// visiteurs annoncés — avec la synthèse des réponses reçues, qui remplace
/// la composition manuelle évoquée au § 2.3 du cahier des charges.
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

  String _linkUrl(String token) =>
      '${LodgeConfig.current.webOrigin}/#/reponse/$token';

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
              for (final d in recipients)
                _DelegationLinkRow(
                  dignitary: d,
                  link: byRecipient[d.id],
                  linkUrl: byRecipient[d.id] != null
                      ? _linkUrl(byRecipient[d.id]!.id)
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
  final Dignitary dignitary;
  final PresenceLink? link;
  final String? linkUrl;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _DelegationLinkRow({
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
        : 'Bonjour ${dignitary.firstName}, merci d\'indiquer via ce lien le '
              'nombre de personnes de votre délégation présentes à la '
              'prochaine tenue : $url';
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
              tooltip: 'Copier le lien',
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
                  'mailto:${dignitary.email.trim()}'
                  '?subject=${Uri.encodeComponent('Décompte de délégation')}'
                  '&body=${Uri.encodeComponent(message)}',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
