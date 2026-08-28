// Fiche membre en lecture seule : mêmes champs que la création/édition
// (member_edit_screen.dart), accessible à tout membre connecté même sans
// droit d'édition.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/member_event.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/fr_date.dart';
import '../widgets/br_decor.dart';
import 'passport_actions.dart';

class MemberDetailScreen extends StatelessWidget {
  final Member member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isSelf = member.id == state.currentUser?.id;
    final loginEmail = member.effectiveLoginEmail;
    final events = state.memberEvents
        .where((e) => e.memberId == member.id)
        .toList()
      ..sort((a, b) {
        final da = a.dateTime;
        final db = b.dateTime;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(member.fullName),
        actions: [
          if (isSelf)
            IconButton(
              tooltip: 'Afficher mon QR (Passeport)',
              icon: const Icon(Icons.qr_code_2, color: BrColors.violet),
              onPressed: () => showMemberPassportQr(context, member),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const BrSectionTitle('IDENTITÉ', icon: Icons.badge_outlined),
          const SizedBox(height: 14),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Prénom', member.firstName),
                _row('Nom', member.lastName),
                _row('Email de contact', member.email),
                _row('Téléphone', member.phone),
                _row('Adresse', member.address),
                _row('Date de naissance', member.birthDate),
                _row('Canal préféré', member.preferredContact,
                    last: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const BrSectionTitle('CONNEXION', icon: Icons.lock_outline),
          const SizedBox(height: 14),
          BrCard(
            child: Text(
              loginEmail.isEmpty ? 'Aucun compte de connexion.' : loginEmail,
              style: const TextStyle(color: BrColors.text),
            ),
          ),
          const SizedBox(height: 24),
          const BrSectionTitle('PARCOURS MAÇONNIQUE',
              icon: Icons.auto_awesome),
          const SizedBox(height: 14),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Matricule', member.matricule),
                _row('Loge mère', member.motherLodge),
                _row('Parrain', member.sponsor),
                _row("Date d'initiation", member.initiationDate),
                _row("Date d'entrée", member.entryDate),
                _row('Office / Fonction', member.function),
                _row('Civilité', member.civilite),
                _row('Grade', member.grade),
                _row('Statut', member.status, last: true),
              ],
            ),
          ),
          if (events.isNotEmpty || member.entryDate.isNotEmpty) ...[
            const SizedBox(height: 24),
            const BrSectionTitle('HISTORIQUE', icon: Icons.history),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tryParseFrDate(member.entryDate) != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.login,
                              size: 16, color: BrColors.muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Entrée le ${member.entryDate}',
                              style: const TextStyle(
                                  color: BrColors.muted, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final e in events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            e.type == kMemberEventElevation
                                ? Icons.trending_up
                                : Icons.swap_horiz,
                            size: 16,
                            color: BrColors.gold,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.fromValue.isEmpty ? '?' : e.fromValue} → ${e.toValue}',
                                  style: const TextStyle(
                                      color: BrColors.text, fontSize: 13),
                                ),
                                Text(
                                  e.note.isEmpty ? e.date : '${e.date} — ${e.note}',
                                  style: const TextStyle(
                                      color: BrColors.muted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const BrSectionTitle('COTISATIONS',
              icon: Icons.account_balance_wallet_outlined),
          const SizedBox(height: 14),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row('Cotisation Loge (€)', '${member.lodgeDues}'),
                _row('Cotisation Ordre (€)', '${member.orderDues}',
                    last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: BrColors.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value.trim().isEmpty ? '—' : value,
            style: const TextStyle(color: BrColors.text, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
