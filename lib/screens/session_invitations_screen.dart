// Invitations d'une Tenue planifiée : trois destinations (groupe WhatsApp de la
// Loge, groupe WhatsApp de l'Obédience, invités par e-mail).
//
// L'API WhatsApp ne permet ni les sondages ni l'envoi dans un groupe : l'app
// prépare le texte et ouvre WhatsApp (choix du groupe par l'utilisateur) ou le
// client mail. La convocation PDF se joint via le partage système.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../models/visitor.dart';
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

class _SessionInvitationsScreenState extends State<SessionInvitationsScreen> {
  final _selectedGuests = <String>{};
  bool _guestsInitialized = false;

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
    final guests = state.visitors
        .where((v) => v.email.trim().isNotEmpty)
        .toList();
    if (!_guestsInitialized) {
      _selectedGuests.addAll(guests.map((v) => v.id));
      _guestsInitialized = true;
    }

    final lodgeText = lodgeInvitationText(session, chrono, ordreDuJour);
    final obedienceText = obedienceInvitationText(
      session,
      state.members,
      chrono,
    );
    final emailText = emailInvitationText(session, chrono, ordreDuJour);
    final recipients = guests
        .where((v) => _selectedGuests.contains(v.id))
        .map((v) => v.email.trim())
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
  final List<Visitor> guests;
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
            for (final v in guests)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selectedGuests.contains(v.id),
                onChanged: onGuestToggle == null
                    ? null
                    : (_) => onGuestToggle!(v.id),
                title: Text(
                  v.fullName,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                ),
                subtitle: Text(
                  [v.email, v.lodge].where((e) => e.isNotEmpty).join(' — '),
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
