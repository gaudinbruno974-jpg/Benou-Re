// Paiement des Agapes d'un corps de Hauts Grades — même principe que
// agape_payment_sessions_screen.dart + agape_payment_screen.dart (loges
// bleues) : liste des tenues avec agape à médaille, puis signature par
// payeur, total encaissé, PDF, archivage Drive.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/agape_payment_service.dart';
import '../services/drive_service.dart';
import '../services/hg_body_service.dart';
import '../services/hg_pdf_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/signature_dialog.dart';

String _sessionLabel(Session s) {
  final number = s.sessionNumber ?? (s.chrono != null ? '${s.chrono}' : '');
  final date = s.dateTime;
  final dateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
  return 'Tenue $number du $dateStr'.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class GrandeLogeHgAgapePaymentSessionsScreen extends StatelessWidget {
  final HgBody body;
  const GrandeLogeHgAgapePaymentSessionsScreen({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Paiement des Agapes — ${body.label}')),
      body: StreamBuilder<List<Session>>(
        stream: HgBodyService.instance.sessionsStream(body),
        builder: (context, snap) {
          final sessions = agapeMedailleSessions(snap.data ?? const []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
            children: [
              const BrSectionTitle(
                'TENUES AVEC MÉDAILLE',
                icon: Icons.restaurant_outlined,
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Aucune Tenue avec agape à médaille.',
                    style: TextStyle(color: BrColors.muted),
                  ),
                ),
              for (final s in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BrCard(
                    accent: BrColors.menuTresorerie,
                    padding: const EdgeInsets.all(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GrandeLogeHgAgapePaymentScreen(
                          body: body,
                          session: s,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sessionLabel(s),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Médaille : ${agapeMedailleAmount(s)} €',
                                style: const TextStyle(
                                  color: BrColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: BrColors.gold,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class GrandeLogeHgAgapePaymentScreen extends StatefulWidget {
  final HgBody body;
  final Session session;
  const GrandeLogeHgAgapePaymentScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  State<GrandeLogeHgAgapePaymentScreen> createState() =>
      _GrandeLogeHgAgapePaymentScreenState();
}

class _GrandeLogeHgAgapePaymentScreenState
    extends State<GrandeLogeHgAgapePaymentScreen> {
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
    final payers = agapePayers(
      session,
      _members,
      _visitors,
      _dignitaries,
      memberObedience: 'GLDB',
      memberLodge: widget.body.label,
    );
    final signatures = session.agapePaymentSignatures;
    final amount = agapeMedailleAmount(session);
    final total = agapeCollectedTotal(
      session,
      _members,
      _visitors,
      _dignitaries,
    );
    final date = session.dateTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement des Agapes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                date != null
                    ? 'Tenue du ${DateFormat('dd/MM/yyyy').format(date)} — médaille $amount €'
                    : 'Médaille $amount €',
                style: const TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          const BrSectionTitle(
            'PRÉSENTS AUX AGAPES',
            icon: Icons.restaurant_outlined,
          ),
          const SizedBox(height: 12),
          if (payers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Personne n\'est annoncé aux agapes : cochez « Agapes » dans '
                '« Présents en tenue ».',
                style: TextStyle(color: BrColors.muted),
              ),
            ),
          for (final p in payers)
            _PayerTile(
              lastName: p.lastName,
              firstName: p.firstName,
              obedience: p.obedience,
              lodge: p.lodge,
              amount: amount,
              signed: (signatures[p.id] ?? '').isNotEmpty,
              onSign: () => _sign(session, p.id, p.fullName),
            ),
          const SizedBox(height: 8),
          BrCard(
            accent: BrColors.menuTresorerie,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total encaissé',
                  style: TextStyle(
                    color: BrColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$total €',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openPdf(context, session),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF Paiement des Agapes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _archive(context, session),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Archiver le PDF sur le Drive'),
          ),
        ],
      ),
    );
  }

  Future<void> _sign(Session session, String payerId, String name) async {
    final dataUrl = await captureSignature(context, name);
    if (dataUrl == null) return;
    final map = Map<String, dynamic>.from(session.toMap());
    final sigs = Map<String, dynamic>.from(
      (map['agapePaymentSignatures'] as Map?) ?? <String, dynamic>{},
    );
    sigs[payerId] = dataUrl;
    map['agapePaymentSignatures'] = sigs;
    await HgBodyService.instance.updateSession(
      widget.body,
      Session.fromMap(session.id, map),
    );
    if (mounted) setState(() {});
  }

  Future<Uint8List> _buildPdf(Session session) async =>
      buildIahMesAgapePaymentPdf(
        widget.body,
        session,
        _members,
        _visitors,
        _dignitaries,
      );

  Future<void> _openPdf(BuildContext context, Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildPdf(session);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'PaiementAgapes_tenue.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  Future<void> _archive(BuildContext context, Session session) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Archivage sur Google Drive...')),
    );
    try {
      final chrono =
          session.chrono?.toInt() ??
          int.tryParse(
            (session.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
          ) ??
          0;
      final dateStr = DateFormat('dd MM yy').format(DateTime.now());
      await DriveService.instance.archiveGenericDocument(
        folderName: 'Tenues ${widget.body.label}',
        fileName: 'Paiement Agapes $chrono ${widget.body.label} $dateStr.pdf',
        bytes: await _buildPdf(session),
      );
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Archivé sur Google Drive.')),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Drive : $e')));
    }
  }
}

class _PayerTile extends StatelessWidget {
  final String lastName;
  final String firstName;
  final String obedience;
  final String lodge;
  final num amount;
  final bool signed;
  final VoidCallback onSign;
  const _PayerTile({
    required this.lastName,
    required this.firstName,
    required this.obedience,
    required this.lodge,
    required this.amount,
    required this.signed,
    required this.onSign,
  });

  @override
  Widget build(BuildContext context) {
    final color = signed ? const Color(0xFF34D399) : BrColors.gold;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: color,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            BrAvatar(firstName: firstName, lastName: lastName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$lastName $firstName'.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [obedience, lodge].where((e) => e.isNotEmpty).join(' — '),
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$amount €',
                    style: const TextStyle(
                      color: BrColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            BrBadge(
              label: signed ? 'Payé' : 'En attente',
              color: color,
              icon: signed ? Icons.check_circle_outline : Icons.schedule,
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onSign,
              child: Text(
                signed ? 'Modifier' : 'Signer',
                style: const TextStyle(color: BrColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
