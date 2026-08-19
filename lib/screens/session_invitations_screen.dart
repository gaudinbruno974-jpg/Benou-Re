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
import '../models/member.dart';
import '../models/presence_link.dart';
import '../models/session.dart';
import '../services/invitation_service.dart';
import '../services/pdf_service.dart';
import '../services/url_opener.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

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
  const _Guest({
    required this.id,
    required this.fullName,
    required this.email,
    required this.lodge,
  });
}

class _SessionInvitationsScreenState extends State<SessionInvitationsScreen> {
  final _selectedGuests = <String>{};
  bool _presenceLinksEnabled = false;

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
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Envoyer sur WhatsApp',
                icon: const Icon(
                  Icons.chat_outlined,
                  size: 18,
                  color: BrColors.teal,
                ),
                onPressed: () => onOpen(
                  'https://wa.me/${_digitsOnly(member.phone)}'
                  '?text=${Uri.encodeComponent(message)}',
                ),
              ),
            if (member.email.trim().isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Envoyer par e-mail',
                icon: const Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: BrColors.violet,
                ),
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

class _InvitationCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BrCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrSectionTitle(title, icon: Icons.send_outlined),
          const SizedBox(height: 10),
          SelectableText(
            text,
            style: const TextStyle(color: BrColors.text, fontSize: 13),
          ),
          if (guests.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Destinataires',
              style: TextStyle(color: BrColors.gold, fontSize: 12),
            ),
            for (final g in guests)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selectedGuests.contains(g.id),
                onChanged: onGuestToggle == null
                    ? null
                    : (_) => onGuestToggle!(g.id),
                title: Text(
                  g.fullName,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                ),
                subtitle: Text(
                  [g.email, g.lodge].where((e) => e.isNotEmpty).join(' — '),
                  style: const TextStyle(color: BrColors.muted, fontSize: 11),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onWhatsApp != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrColors.teal,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Envoyer sur WhatsApp'),
                  onPressed: onWhatsApp,
                ),
              if (onEmail != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrColors.violet,
                  ),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Envoyer par e-mail'),
                  onPressed: onEmail,
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copier'),
                onPressed: onCopy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
