// Invitations d'une Tenue de Hauts Grades planifiée : un lien de réponse
// individuel par destinataire — « Convocation » pour les membres du corps
// (Flux A, réponse nominative Présent/Absent/Agapes), « Invitation » pour
// les dignitaires invités (Flux B, décompte global de délégation, sans
// répartition par grade — confirmé par l'utilisateur, à la différence des
// loges bleues). Même principe que session_invitations_screen.dart (loges
// bleues), adapté à HgBodyService/HgPresenceLink au lieu d'AppState/
// PresenceLink. La convocation PDF se joint via le partage système.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_presence_link.dart';
import '../models/member.dart';
import '../models/preferred_contact.dart';
import '../models/session.dart';
import '../services/bulk_email_service.dart';
import '../services/email_link.dart';
import '../services/hg_body_service.dart';
import '../services/hg_invitation_service.dart';
import '../services/hg_pdf_service.dart';
import '../services/pdf_service.dart' show plancheOrdreDuJour;
import '../services/url_opener.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

int _chronoOf(Session s) {
  if (s.chrono != null) return s.chrono!.toInt();
  return int.tryParse(
        (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
      ) ??
      0;
}

String _linkUrl(String token) =>
    '${LodgeConfig.current.webOrigin}/#/reponse-hg/$token';

class GrandeLogeHgSessionInvitationsScreen extends StatefulWidget {
  final HgBody body;
  final Session session;
  const GrandeLogeHgSessionInvitationsScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  State<GrandeLogeHgSessionInvitationsScreen> createState() =>
      _GrandeLogeHgSessionInvitationsScreenState();
}

class _GrandeLogeHgSessionInvitationsScreenState
    extends State<GrandeLogeHgSessionInvitationsScreen> {
  bool _presenceLinksEnabled = false;
  bool _delegationLinksEnabled = false;

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

  Future<void> _shareConvocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await buildIahMesConvocationPdf(
        widget.body,
        widget.session,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Convocation ${widget.body.label} Tenue '
            '${_chronoOf(widget.session)}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chrono = _chronoOf(widget.session);
    final ordreDuJour = plancheOrdreDuJour(widget.session);

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
            onPressed: _shareConvocation,
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
                    'Convocation ${widget.body.label}',
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
                  _MemberLinksSection(
                    body: widget.body,
                    session: widget.session,
                    chrono: chrono,
                    ordreDuJour: ordreDuJour,
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
                    'Chaque dignitaire invité reçoit un lien pour déclarer '
                    'sa présence et le nombre de personnes de sa délégation, '
                    'sans se connecter.',
                    style: TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                ),
                if (_delegationLinksEnabled)
                  _DelegationLinksSection(
                    body: widget.body,
                    session: widget.session,
                    chrono: chrono,
                    ordreDuJour: ordreDuJour,
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

/// Section « Convocation » (Flux A) : un lien par membre du corps — tous
/// éligibles, sans filtre par degré (même principe que les Présences —
/// grande_loge_hg_presence_screen.dart n'a pas non plus ce filtre).
class _MemberLinksSection extends StatefulWidget {
  final HgBody body;
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _MemberLinksSection({
    required this.body,
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  State<_MemberLinksSection> createState() => _MemberLinksSectionState();
}

class _MemberLinksSectionState extends State<_MemberLinksSection> {
  bool _generating = false;
  final Set<String> _selectedIds = {};
  bool _sendingBulk = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;

  Future<void> _generateMissing(
    List<Member> eligible,
    List<HgPresenceLink> existing,
  ) async {
    final dt = widget.session.dateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La tenue doit avoir une date pour générer les liens.'),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    final expiresAt = DateTime(dt.year, dt.month, dt.day);
    final existingMemberIds = existing.map((l) => l.memberId).toSet();
    final sessionLabel = hgInvitationTitle(widget.session, widget.chrono);
    final sessionDateLabel = hgInvitationTitle(widget.session, widget.chrono);
    for (final m in eligible) {
      if (existingMemberIds.contains(m.id)) continue;
      await HgBodyService.instance.createHgPresenceLink(
        HgPresenceLink(
          id: generateHgPresenceToken(),
          bodyKey: widget.body.key,
          sessionId: widget.session.id,
          memberId: m.id,
          memberName: m.fullName,
          sessionLabel: sessionLabel,
          sessionDateLabel: sessionDateLabel,
          sessionType: widget.session.typeLabel,
          sessionDegreeLabel: hgDegreeOrdinalPhrase(
            widget.body,
            int.tryParse(
                  widget.session.degreTravail ?? widget.session.degree,
                ) ??
                4,
          ),
          hasAgape: widget.session.suitAgapes,
          expiresAt: expiresAt,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _sendSelected(
    List<Member> eligible,
    Map<String, HgPresenceLink> byMember,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final targets = eligible
        .where((m) => _selectedIds.contains(m.id) && byMember[m.id] != null)
        .toList();
    if (targets.isEmpty) return;
    setState(() {
      _sendingBulk = true;
      _bulkDone = 0;
      _bulkTotal = targets.length;
    });
    try {
      final pdfBytes = await buildIahMesConvocationPdf(
        widget.body,
        widget.session,
      );
      final recipients = [
        for (final m in targets)
          (
            email: m.email,
            subject: hgMemberConvocationSubject(
              widget.body,
              widget.session,
              widget.chrono,
            ),
            body: hgMemberConvocationBody(
              widget.body,
              widget.session,
              widget.ordreDuJour,
              _linkUrl(byMember[m.id]!.id),
              recipient: m,
            ),
          ),
      ];
      final result = await sendBulkGmails(
        pdfBytes: pdfBytes,
        attachmentName:
            'Convocation ${widget.body.label} Tenue '
            '${widget.chrono}.pdf',
        recipients: recipients,
        onProgress: (done, total) {
          if (mounted) setState(() => _bulkDone = done);
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(result.summary)));
      setState(() => _selectedIds.clear());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _sendingBulk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Member>>(
      stream: HgBodyService.instance.membersStream(widget.body),
      builder: (context, memberSnap) {
        final eligible = memberSnap.data ?? const <Member>[];
        return StreamBuilder<List<HgPresenceLink>>(
          stream: HgBodyService.instance.hgPresenceLinksForSessionStream(
            widget.body,
            widget.session.id,
          ),
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <HgPresenceLink>[];
            final existing = all
                .where((l) => l.kind == kHgPresenceLinkKindMember)
                .toList();
            final byMember = {for (final l in existing) l.memberId: l};
            final missing = eligible
                .where((m) => !byMember.containsKey(m.id))
                .length;
            final selectableIds = eligible
                .where((m) => byMember.containsKey(m.id))
                .map((m) => m.id)
                .toSet();
            final allSelected =
                selectableIds.isNotEmpty &&
                selectableIds.every(_selectedIds.contains);

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.link, size: 16),
                        label: Text('Générer les liens ($missing manquant(s))'),
                        onPressed: _generating
                            ? null
                            : () => _generateMissing(eligible, existing),
                      ),
                    ),
                  if (selectableIds.isNotEmpty) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: allSelected,
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selectedIds.addAll(selectableIds);
                        } else {
                          _selectedIds.removeAll(selectableIds);
                        }
                      }),
                      title: const Text(
                        'Envoi groupé (tout sélectionner)',
                        style: TextStyle(color: BrColors.text, fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: BrColors.violet,
                        ),
                        icon: _sendingBulk
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.mail_outline, size: 16),
                        label: Text(
                          _sendingBulk
                              ? 'Envoi $_bulkDone/$_bulkTotal…'
                              : 'Envoyer la sélection (${_selectedIds.length})',
                        ),
                        onPressed: _sendingBulk || _selectedIds.isEmpty
                            ? null
                            : () => _sendSelected(eligible, byMember),
                      ),
                    ),
                  ],
                  for (final m in eligible)
                    _MemberLinkRow(
                      body: widget.body,
                      session: widget.session,
                      chrono: widget.chrono,
                      ordreDuJour: widget.ordreDuJour,
                      member: m,
                      link: byMember[m.id],
                      selected: _selectedIds.contains(m.id),
                      onSelectedChanged: byMember[m.id] == null
                          ? null
                          : (v) => setState(() {
                              if (v ?? false) {
                                _selectedIds.add(m.id);
                              } else {
                                _selectedIds.remove(m.id);
                              }
                            }),
                      onCopy: widget.onCopy,
                      onOpen: widget.onOpen,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MemberLinkRow extends StatelessWidget {
  final HgBody body;
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final Member member;
  final HgPresenceLink? link;
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _MemberLinkRow({
    required this.body,
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.member,
    required this.link,
    required this.selected,
    required this.onSelectedChanged,
    required this.onCopy,
    required this.onOpen,
  });

  Color get _statusColor {
    switch (link?.status) {
      case kHgPresenceStatusPresent:
        return BrColors.menuVisiteurs;
      case kHgPresenceStatusAbsent:
        return BrColors.menuTresorerie;
      default:
        return BrColors.muted;
    }
  }

  String get _statusLabel {
    switch (link?.status) {
      case kHgPresenceStatusPresent:
        return 'Présent${link?.agapePresent == true ? ' + agapes' : ''}';
      case kHgPresenceStatusAbsent:
        return 'Absent';
      default:
        return link == null ? 'Lien non généré' : 'En attente';
    }
  }

  String _digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

  @override
  Widget build(BuildContext context) {
    final l = link;
    final message = l == null
        ? ''
        : hgMemberConvocationBody(
            body,
            session,
            ordreDuJour,
            _linkUrl(l.id),
            recipient: member,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: selected,
              onChanged: onSelectedChanged,
              side: const BorderSide(color: BrColors.muted),
            ),
          ),
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
          if (l != null) ...[
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
                  emailComposeUrl(
                    to: member.email.trim(),
                    subject: hgMemberConvocationSubject(body, session, chrono),
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

/// Section « Invitation » (Flux B) : un lien par dignitaire invité — même
/// collection que l'écran Dignitaires du corps.
class _DelegationLinksSection extends StatefulWidget {
  final HgBody body;
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _DelegationLinksSection({
    required this.body,
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.onCopy,
    required this.onOpen,
  });

  @override
  State<_DelegationLinksSection> createState() =>
      _DelegationLinksSectionState();
}

class _DelegationLinksSectionState extends State<_DelegationLinksSection> {
  bool _generating = false;
  final Set<String> _selectedIds = {};
  bool _sendingBulk = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;

  Future<void> _generateMissing(
    List<Dignitary> recipients,
    List<HgPresenceLink> existing,
  ) async {
    final dt = widget.session.dateTime;
    if (dt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La tenue doit avoir une date pour générer les liens.'),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    final expiresAt = DateTime(dt.year, dt.month, dt.day);
    final existingRecipientIds = existing.map((l) => l.recipientId).toSet();
    final sessionLabel = hgInvitationTitle(widget.session, widget.chrono);
    for (final d in recipients) {
      if (existingRecipientIds.contains(d.id)) continue;
      await HgBodyService.instance.createHgPresenceLink(
        HgPresenceLink(
          id: generateHgPresenceToken(),
          bodyKey: widget.body.key,
          kind: kHgPresenceLinkKindDelegation,
          sessionId: widget.session.id,
          sessionLabel: sessionLabel,
          sessionDateLabel: sessionLabel,
          sessionType: widget.session.typeLabel,
          sessionDegreeLabel: hgDegreeOrdinalPhrase(
            widget.body,
            int.tryParse(
                  widget.session.degreTravail ?? widget.session.degree,
                ) ??
                4,
          ),
          hasAgape: widget.session.suitAgapes,
          recipientId: d.id,
          recipientName: d.fullName,
          recipientAlone: dignitaryComesAlone(d),
          expiresAt: expiresAt,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _generating = false);
  }

  Future<void> _sendSelected(
    List<Dignitary> recipients,
    Map<String, HgPresenceLink> byRecipient,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final targets = recipients
        .where((d) => _selectedIds.contains(d.id) && byRecipient[d.id] != null)
        .toList();
    if (targets.isEmpty) return;
    setState(() {
      _sendingBulk = true;
      _bulkDone = 0;
      _bulkTotal = targets.length;
    });
    try {
      final pdfBytes = await buildIahMesConvocationPdf(
        widget.body,
        widget.session,
      );
      final recipientsToSend = [
        for (final d in targets)
          (
            email: d.email,
            subject: hgDignitaryInvitationSubject(
              widget.body,
              widget.session,
              widget.chrono,
            ),
            body: hgDignitaryInvitationBody(
              widget.body,
              widget.session,
              widget.ordreDuJour,
              _linkUrl(byRecipient[d.id]!.id),
              recipient: d,
            ),
          ),
      ];
      final result = await sendBulkGmails(
        pdfBytes: pdfBytes,
        attachmentName:
            'Convocation ${widget.body.label} Tenue '
            '${widget.chrono}.pdf',
        recipients: recipientsToSend,
        onProgress: (done, total) {
          if (mounted) setState(() => _bulkDone = done);
        },
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(result.summary)));
      setState(() => _selectedIds.clear());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _sendingBulk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Dignitary>>(
      stream: HgBodyService.instance.dignitariesStream(widget.body),
      builder: (context, dignitarySnap) {
        final recipients =
            (dignitarySnap.data ?? const <Dignitary>[])
                .where(
                  (d) => d.email.trim().isNotEmpty || d.phone.trim().isNotEmpty,
                )
                .toList()
              ..sort((a, b) => a.lastName.compareTo(b.lastName));

        return StreamBuilder<List<HgPresenceLink>>(
          stream: HgBodyService.instance.hgPresenceLinksForSessionStream(
            widget.body,
            widget.session.id,
          ),
          builder: (context, snapshot) {
            final all = snapshot.data ?? const <HgPresenceLink>[];
            final existing = all
                .where((l) => l.kind == kHgPresenceLinkKindDelegation)
                .toList();
            final byRecipient = {for (final l in existing) l.recipientId: l};
            for (final d in recipients) {
              final l = byRecipient[d.id];
              if (l == null) continue;
              final shouldBeAlone = dignitaryComesAlone(d);
              if (l.recipientAlone != shouldBeAlone) {
                unawaited(
                  HgBodyService.instance.syncHgPresenceLinkRecipientAlone(
                    l.id,
                    shouldBeAlone,
                  ),
                );
              }
            }
            final missing = recipients
                .where((d) => !byRecipient.containsKey(d.id))
                .length;
            final answered = existing.where((l) => l.isAnswered).toList();
            final totalDelegation = answered.fold<int>(
              0,
              (sum, l) => sum + (l.delegationCount ?? 0),
            );
            final selectableIds = recipients
                .where((d) => byRecipient.containsKey(d.id))
                .map((d) => d.id)
                .toSet();
            final allSelected =
                selectableIds.isNotEmpty &&
                selectableIds.every(_selectedIds.contains);

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                      child: BrBadge(
                        label: '$totalDelegation personne(s) en délégation',
                        color: BrColors.gold,
                      ),
                    ),
                  if (selectableIds.isNotEmpty) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: allSelected,
                      onChanged: (v) => setState(() {
                        if (v ?? false) {
                          _selectedIds.addAll(selectableIds);
                        } else {
                          _selectedIds.removeAll(selectableIds);
                        }
                      }),
                      title: const Text(
                        'Envoi groupé (tout sélectionner)',
                        style: TextStyle(color: BrColors.text, fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: BrColors.violet,
                        ),
                        icon: _sendingBulk
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.mail_outline, size: 16),
                        label: Text(
                          _sendingBulk
                              ? 'Envoi $_bulkDone/$_bulkTotal…'
                              : 'Envoyer la sélection (${_selectedIds.length})',
                        ),
                        onPressed: _sendingBulk || _selectedIds.isEmpty
                            ? null
                            : () => _sendSelected(recipients, byRecipient),
                      ),
                    ),
                  ],
                  for (final d in recipients)
                    _DelegationLinkRow(
                      body: widget.body,
                      session: widget.session,
                      chrono: widget.chrono,
                      ordreDuJour: widget.ordreDuJour,
                      dignitary: d,
                      link: byRecipient[d.id],
                      selected: _selectedIds.contains(d.id),
                      onSelectedChanged: byRecipient[d.id] == null
                          ? null
                          : (v) => setState(() {
                              if (v ?? false) {
                                _selectedIds.add(d.id);
                              } else {
                                _selectedIds.remove(d.id);
                              }
                            }),
                      onCopy: widget.onCopy,
                      onOpen: widget.onOpen,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

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
  final HgBody body;
  final Session session;
  final int chrono;
  final List<String> ordreDuJour;
  final Dignitary dignitary;
  final HgPresenceLink? link;
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;
  final Future<void> Function(String) onCopy;
  final Future<void> Function(String) onOpen;
  const _DelegationLinkRow({
    required this.body,
    required this.session,
    required this.chrono,
    required this.ordreDuJour,
    required this.dignitary,
    required this.link,
    required this.selected,
    required this.onSelectedChanged,
    required this.onCopy,
    required this.onOpen,
  });

  String get _statusLabel {
    final l = link;
    if (l == null) return 'Lien non généré';
    if (!l.isAnswered) return 'En attente';
    if (l.recipientAlone) {
      final label = l.status == kHgPresenceStatusPresent
          ? 'Présent'
          : (l.status == kHgPresenceStatusAbsent ? 'Absent' : 'En attente');
      final agapeLabel = l.agapePresent == true ? ' + agapes' : '';
      return '$label$agapeLabel';
    }
    final ownLabel = l.status == kHgPresenceStatusPresent
        ? 'Présent'
        : (l.status == kHgPresenceStatusAbsent ? 'Absent' : 'En attente');
    final ownAgapeLabel = l.recipientAgapePresent == true ? ' + agapes' : '';
    return '$ownLabel$ownAgapeLabel · délégation : '
        '${l.delegationCount ?? 0} personne(s)';
  }

  Color get _statusColor {
    final l = link;
    if (l == null || !l.isAnswered) return BrColors.muted;
    if (l.status == kHgPresenceStatusAbsent) return BrColors.menuTresorerie;
    return BrColors.menuVisiteurs;
  }

  String _digitsOnly(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');

  @override
  Widget build(BuildContext context) {
    final l = link;
    final message = l == null
        ? ''
        : hgDignitaryInvitationBody(
            body,
            session,
            ordreDuJour,
            _linkUrl(l.id),
            recipient: dignitary,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: selected,
              onChanged: onSelectedChanged,
              side: const BorderSide(color: BrColors.muted),
            ),
          ),
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
          if (l != null) ...[
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
                  emailComposeUrl(
                    to: dignitary.email.trim(),
                    subject: hgDignitaryInvitationSubject(
                      body,
                      session,
                      chrono,
                    ),
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
