// Paiement des Agapes : choix de la Tenue.
// Seules les Tenues « Agape avec médaille » donnent lieu à un paiement.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/agape_payment_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'agape_payment_screen.dart';

class AgapePaymentSessionsScreen extends StatelessWidget {
  const AgapePaymentSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sessions = agapeMedailleSessions(state.sessions);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement des Agapes')),
      body: ListView(
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
                    builder: (_) => AgapePaymentScreen(sessionId: s.id),
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
      ),
    );
  }
}

String _sessionLabel(Session s) {
  final number = s.sessionNumber ?? (s.chrono != null ? '${s.chrono}' : '');
  final date = s.dateTime;
  final dateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
  return 'Tenue $number du $dateStr'.replaceAll(RegExp(r'\s+'), ' ').trim();
}
