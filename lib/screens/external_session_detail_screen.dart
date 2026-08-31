// Détail d'une invitation reçue (Registre des Tenues extérieures) :
// informations complètes, pièce jointe, diffusion aux membres — même
// mécanisme que les Convocations internes (liens de réponse individuels,
// envoi groupé, voir session_invitations_screen.dart) — et suivi de
// participation modifiable à tout moment, y compris manuellement (une
// personne qui a confirmé par téléphone sans répondre au lien).
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/external_session.dart';
import '../models/member.dart';
import '../models/presence_link.dart';
import '../models/session.dart' show Session;
import '../services/bulk_email_service.dart';
import '../services/drive_service.dart';
import '../services/external_invitation_service.dart';
import '../services/url_opener.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'external_session_edit_screen.dart';

class ExternalSessionDetailScreen extends StatefulWidget {
  final String externalSessionId;
  const ExternalSessionDetailScreen({
    super.key,
    required this.externalSessionId,
  });

  @override
  State<ExternalSessionDetailScreen> createState() =>
      _ExternalSessionDetailScreenState();
}

class _ExternalSessionDetailScreenState
    extends State<ExternalSessionDetailScreen> {
  bool _generating = false;
  bool _sendingBulk = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  final Set<String> _selectedIds = {};

  String _linkUrl(String token) =>
      '${LodgeConfig.current.webOrigin}/#/reponse/$token';

  Future<void> _generateMissing(
    ExternalSession session,
    List<Member> eligible,
    List<PresenceLink> existing,
  ) async {
    setState(() => _generating = true);
    final state = context.read<AppState>();
    final expiresAt = session.dateTime ?? DateTime.now().add(const Duration(days: 30));
    final sessionDateLabel = session.dateTime == null
        ? 'date à définir'
        : DateFormat('EEEE d MMMM y', 'fr_FR').format(session.dateTime!);
    final existingIds = existing.map((l) => l.memberId).toSet();
    for (final m in eligible) {
      if (existingIds.contains(m.id)) continue;
      await state.createPresenceLink(
        PresenceLink(
          id: generatePresenceToken(),
          kind: kPresenceLinkKindExternal,
          sessionId: session.id,
          memberId: m.id,
          memberName: m.fullName,
          sessionLabel: 'Tenue de la ${session.organizingLodge}',
          sessionDateLabel: sessionDateLabel,
          sessionType: session.eventTypeLabel,
          sessionDegreeLabel: session.degree == kExternalDegreeAll
              ? 'Tous'
              : Session.degreeOrdinal(session.degree),
          hasAgape: true,
          expiresAt: expiresAt,
          createdAt: DateTime.now(),
        ),
      );
    }
    if (mounted) setState(() => _generating = false);
  }

  /// Envoi groupé : un brouillon Gmail personnalisé par membre coché, tous
  /// avec le même carton (photo/PDF) joint — retéléchargé une seule fois
  /// depuis Drive s'il existe, aucune pièce jointe sinon.
  Future<void> _sendSelected(
    ExternalSession session,
    List<Member> eligible,
    Map<String, PresenceLink> byMember,
    List<Member> allMembers,
    String lodgeVmName,
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
      Uint8List? attachmentBytes;
      if (session.attachmentFileId.isNotEmpty) {
        try {
          attachmentBytes =
              await DriveService.instance.downloadFile(session.attachmentFileId);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Pièce jointe non récupérée ($e) — envoi sans carton.')),
          );
        }
      }
      final recipients = [
        for (final m in targets)
          (
            email: m.email,
            subject: externalInvitationSubject(session),
            body: externalInvitationBody(
              session,
              allMembers,
              _linkUrl(byMember[m.id]!.id),
              lodgeVmName: lodgeVmName,
              recipient: m,
            ),
          ),
      ];
      final result = await sendBulkGmails(
        pdfBytes: attachmentBytes,
        attachmentName:
            attachmentBytes == null ? null : session.attachmentFileName,
        attachmentContentType: session.attachmentContentType.isEmpty
            ? 'application/pdf'
            : session.attachmentContentType,
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

  Future<void> _toggleAttending(ExternalSession session, String memberId) async {
    final state = context.read<AppState>();
    final attending = List<String>.from(session.attendingMemberIds);
    if (attending.contains(memberId)) {
      attending.remove(memberId);
    } else {
      attending.add(memberId);
    }
    await state.updateExternalSession(
      session.copyWith(attendingMemberIds: attending),
    );
  }

  Future<void> _toggleAgape(ExternalSession session, String memberId) async {
    final state = context.read<AppState>();
    final agapes = List<String>.from(session.agapeIds);
    if (agapes.contains(memberId)) {
      agapes.remove(memberId);
    } else {
      agapes.add(memberId);
    }
    await state.updateExternalSession(session.copyWith(agapeIds: agapes));
  }

  Future<void> _confirmDelete(ExternalSession session) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text(
          'Supprimer cette invitation ?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'L\'invitation de la ${session.organizingLodge} sera '
          'définitivement supprimée.',
          style: const TextStyle(color: BrColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFB7185))),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await state.deleteExternalSession(session.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.externalSessions
        .where((s) => s.id == widget.externalSessionId)
        .firstOrNull;
    if (session == null) {
      return const Scaffold(
        body: Center(
          child: Text('Invitation introuvable.', style: TextStyle(color: BrColors.muted)),
        ),
      );
    }
    final canEdit = canEditSessions(state.currentUser);
    final eligible = [...eligibleExternalRecipients(session.degree, state.members)]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    return Scaffold(
      appBar: AppBar(
        title: Text(session.organizingLodge),
        actions: canEdit
            ? [
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExternalSessionEditScreen(session: session),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(session),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          BrCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    BrBadge(label: session.eventTypeLabel, color: BrColors.gold),
                    BrBadge(label: session.degree, color: BrColors.teal),
                    if (session.isPast)
                      const BrBadge(label: 'Passée', color: BrColors.muted),
                    BrBadge(
                      label: '${session.attendingMemberIds.length} présent(s)',
                      color: BrColors.menuVisiteurs,
                    ),
                    BrBadge(
                      label: '${session.agapeIds.length} aux Agapes',
                      color: BrColors.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  session.dateTime == null
                      ? 'Date à définir'
                      : DateFormat('EEEE d MMMM y à HH:mm', 'fr_FR').format(session.dateTime!),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (session.obedience.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(session.obedience,
                        style: const TextStyle(color: BrColors.muted, fontSize: 12.5)),
                  ),
                if (session.location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(session.location,
                        style: const TextStyle(color: BrColors.muted, fontSize: 12.5)),
                  ),
                if (session.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(session.notes, style: const TextStyle(color: BrColors.text, fontSize: 13)),
                ],
                if (session.attachmentDriveUrl.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: Text('Voir le carton (${session.attachmentFileName})'),
                    onPressed: () => openExternalUrl(session.attachmentDriveUrl),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (canEdit) ...[
            const BrSectionTitle('DIFFUSION AUX MEMBRES', icon: Icons.campaign_outlined),
            const SizedBox(height: 12),
            _buildDiffusionSection(session, eligible, state),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffusionSection(
    ExternalSession session,
    List<Member> eligible,
    AppState state,
  ) {
    return StreamBuilder<List<PresenceLink>>(
      stream: state.presenceLinksForSession(session.id),
      builder: (context, snapshot) {
        final existing = (snapshot.data ?? const <PresenceLink>[])
            .where((l) => l.kind == kPresenceLinkKindExternal)
            .toList();
        final byMember = {for (final l in existing) l.memberId: l};
        final missing = eligible.where((m) => !byMember.containsKey(m.id)).length;
        final selectableIds =
            eligible.where((m) => byMember.containsKey(m.id)).map((m) => m.id).toSet();
        final allSelected =
            selectableIds.isNotEmpty && selectableIds.every(_selectedIds.contains);

        return Column(
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
                      : () => _generateMissing(session, eligible, existing),
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
                  style: FilledButton.styleFrom(backgroundColor: BrColors.violet),
                  icon: _sendingBulk
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mail_outline, size: 16),
                  label: Text(
                    _sendingBulk
                        ? 'Envoi $_bulkDone/$_bulkTotal…'
                        : 'Envoyer la sélection (${_selectedIds.length})',
                  ),
                  onPressed: _sendingBulk || _selectedIds.isEmpty
                      ? null
                      : () => _sendSelected(
                            session,
                            eligible,
                            byMember,
                            state.members,
                            state.lodgeVmName,
                          ),
                ),
              ),
            ],
            for (final m in eligible)
              _MemberRow(
                member: m,
                link: byMember[m.id],
                attending: session.attendingMemberIds.contains(m.id),
                agape: session.agapeIds.contains(m.id),
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
                onToggleAttending: () => _toggleAttending(session, m.id),
                onToggleAgape: () => _toggleAgape(session, m.id),
              ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Member member;
  final PresenceLink? link;
  final bool attending;
  final bool agape;
  final bool selected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback onToggleAttending;
  final VoidCallback onToggleAgape;
  const _MemberRow({
    required this.member,
    required this.link,
    required this.attending,
    required this.agape,
    required this.selected,
    required this.onSelectedChanged,
    required this.onToggleAttending,
    required this.onToggleAgape,
  });

  String get _statusLabel {
    if (link == null) return 'Lien non généré';
    if (!link!.isAnswered) return 'En attente de réponse';
    if (link!.status != kPresenceStatusPresent) return 'A répondu Absent';
    return link!.agapePresent == true
        ? 'A répondu Présent (+ Agapes)'
        : 'A répondu Présent';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BrCard(
        accent: attending ? BrColors.menuVisiteurs : BrColors.muted,
        padding: const EdgeInsets.all(12),
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
                  Text(member.fullName,
                      style: const TextStyle(color: BrColors.text, fontSize: 13)),
                  Text(_statusLabel,
                      style: const TextStyle(color: BrColors.muted, fontSize: 11)),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: attending ? BrColors.menuVisiteurs : BrColors.muted,
                side: BorderSide(
                  color: attending ? BrColors.menuVisiteurs : BrColors.muted,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onToggleAttending,
              child: Text(attending ? 'Présent Tenue' : 'Marquer présent'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: agape ? BrColors.violet : BrColors.muted,
                side: BorderSide(color: agape ? BrColors.violet : BrColors.muted),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onToggleAgape,
              child: Text(agape ? 'Présent Agapes' : 'Marquer agapes'),
            ),
          ],
        ),
      ),
    );
  }
}
