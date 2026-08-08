// Paiement des Agapes d'une Tenue : chaque payeur signe le règlement de sa
// médaille, le total encaissé est affiché, et le PDF signé est archivé dans le
// dossier Drive de la Tenue.
//
// L'écran reste utilisable après la Tenue : les paiements se règlent souvent
// le soir même ou plus tard, une Tenue suspendue ne bloque donc rien ici.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/agape_payment_service.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/signature_dialog.dart';

class AgapePaymentScreen extends StatelessWidget {
  final String sessionId;
  const AgapePaymentScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => Session(id: sessionId),
    );
    final payers = agapePayers(session, state.members, state.visitors);
    final signatures = session.agapePaymentSignatures;
    final amount = agapeMedailleAmount(session);
    final total = agapeCollectedTotal(session, state.members, state.visitors);
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
                'Personne n\'est annoncé aux agapes : cochez « Agapes » dans « Présents en tenue ».',
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
              onSign: () => _sign(context, session, p.id, p.fullName),
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

  Future<void> _sign(
    BuildContext context,
    Session session,
    String payerId,
    String name,
  ) async {
    final state = context.read<AppState>();
    final dataUrl = await captureSignature(context, name);
    if (dataUrl == null) return;
    final map = Map<String, dynamic>.from(session.toMap());
    final sigs = Map<String, dynamic>.from(
      (map['agapePaymentSignatures'] as Map?) ?? <String, dynamic>{},
    );
    sigs[payerId] = dataUrl;
    map['agapePaymentSignatures'] = sigs;
    await state.updateSession(Session.fromMap(session.id, map));
  }

  Future<Uint8List> _buildPdf(AppState state, Session session) async =>
      buildAgapePaymentPdf(session, state.members, state.visitors);

  Future<void> _openPdf(BuildContext context, Session session) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _buildPdf(state, session);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'PaiementAgapes_tenue.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  Future<void> _archive(BuildContext context, Session session) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Archivage sur Google Drive...')),
    );
    try {
      final chrono = session.chrono?.toInt() ??
          int.tryParse((session.sessionNumber ?? '')
              .replaceAll(RegExp(r'[^\d]'), '')) ??
          0;
      final email = await DriveService.instance.archivePdfs(session, {
        'PaiementAgapes_Tenue_$chrono.pdf': await _buildPdf(state, session),
      });
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Archivé sur Google Drive ($email).')),
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
                    style: const TextStyle(
                      color: BrColors.muted,
                      fontSize: 12,
                    ),
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
