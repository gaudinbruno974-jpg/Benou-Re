// Trésorerie — parité avec src/components/TreasuryScreen.tsx.
// Deux onglets : Cotisations (Loge / Ordre / Grades, encaissé vs à percevoir)
// et Tronc de la Veuve (total récolté + historique des tenues).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _emerald = Color(0xFF34D399);
const _rose = Color(0xFFFB7185);

bool _canEditTreasury(Member? u) {
  if (u == null) return false;
  if (u.isAdmin) return true;
  final f = u.function.trim().toLowerCase();
  if (f.contains('trésorier') ||
      f.contains('tresorier') ||
      f.contains('vénérable') ||
      f.contains('venerable')) {
    return true;
  }
  const admins = {
    'vm@loge.com',
    'gaudin.bruno974@gmail.com',
    'benoure974@gmail.com',
  };
  return admins.contains(u.email.toLowerCase());
}

class TreasuryScreen extends StatelessWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canEdit = _canEditTreasury(state.currentUser);
    final members = [...state.members]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trésorerie de la Loge'),
          bottom: const TabBar(
            indicatorColor: BrColors.gold,
            labelColor: BrColors.goldBright,
            unselectedLabelColor: BrColors.muted,
            tabs: [
              Tab(icon: Icon(Icons.groups_outlined), text: 'Cotisations'),
              Tab(icon: Icon(Icons.savings_outlined), text: 'Tronc de la Veuve'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CotisationsTab(members: members, canEdit: canEdit),
            _TroncTab(sessions: state.sessions),
          ],
        ),
      ),
    );
  }
}

class _CotisationsTab extends StatelessWidget {
  final List<Member> members;
  final bool canEdit;
  const _CotisationsTab({required this.members, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    num collected = 0;
    num pending = 0;
    for (final m in members) {
      m.lodgeDuesPaid ? collected += m.lodgeDues : pending += m.lodgeDues;
      m.orderDuesPaid ? collected += m.orderDues : pending += m.orderDues;
      if (m.elevationDues > 0) {
        m.elevationDuesPaid
            ? collected += m.elevationDues
            : pending += m.elevationDues;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _Counter(
                label: 'TOTAL ENCAISSÉ',
                value: collected,
                hint: 'Reçu en banque de loge',
                color: _emerald),
            const SizedBox(width: 12),
            _Counter(
                label: 'À PERCEVOIR',
                value: pending,
                hint: 'Relances à envoyer',
                color: BrColors.gold),
          ],
        ),
        const SizedBox(height: 16),
        if (!canEdit)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BrColors.gold.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: BrColors.gold),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode consultation. Seuls le VM et le Trésorier peuvent modifier les paiements.',
                    style: TextStyle(color: BrColors.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text('DÉTAIL DES COMPTES INDIVIDUELS (${members.length})',
            style: const TextStyle(
                color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 12),
        for (final m in members)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.fullName.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(
                    '${m.grade} • ${m.function != 'Aucun' ? m.function : 'Membre'}',
                    style: const TextStyle(color: BrColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DueChip(
                        label: 'LOGE',
                        amount: m.lodgeDues,
                        paid: m.lodgeDuesPaid,
                        onTap: canEdit
                            ? () => state.updateMember(
                                m.copyWith(lodgeDuesPaid: !m.lodgeDuesPaid))
                            : null,
                      ),
                      _DueChip(
                        label: 'ORDRE',
                        amount: m.orderDues,
                        paid: m.orderDuesPaid,
                        onTap: canEdit
                            ? () => state.updateMember(
                                m.copyWith(orderDuesPaid: !m.orderDuesPaid))
                            : null,
                      ),
                      if (m.elevationDues > 0)
                        _DueChip(
                          label: 'GRADES',
                          amount: m.elevationDues,
                          paid: m.elevationDuesPaid,
                          onTap: canEdit
                              ? () => state.updateMember(m.copyWith(
                                  elevationDuesPaid: !m.elevationDuesPaid))
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TroncTab extends StatelessWidget {
  final List<Session> sessions;
  const _TroncTab({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final withTronc = sessions.where((s) => s.troncAmount > 0).toList();
    final total =
        sessions.fold<num>(0, (acc, s) => acc + (s.troncAmount));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet,
                    size: 40, color: BrColors.gold),
                const SizedBox(height: 8),
                const Text('CAISSE GÉNÉRALE DU TRONC',
                    style: TextStyle(
                        color: BrColors.muted,
                        fontSize: 11,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('${total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        color: BrColors.gold,
                        fontSize: 34,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  "Fonds dédiés aux œuvres de bienfaisance et à l'aide aux veuves et orphelins de l'atelier.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BrColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('HISTORIQUE DES TENUES (${withTronc.length})',
            style: const TextStyle(
                color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 12),
        if (withTronc.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BrColors.muted.withValues(alpha: 0.3)),
            ),
            child: const Text(
                "Aucun tronc de la veuve n'a encore été récolté.",
                style: TextStyle(color: BrColors.muted)),
          )
        else
          for (final s in withTronc)
            Card(
              child: ListTile(
                title: Text(
                  s.title.isNotEmpty
                      ? s.title
                      : 'Tenue au ${s.degreeLabel}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Grade : ${s.degreeLabel} • ${_fmtDate(s)}',
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _emerald.withValues(alpha: 0.3)),
                  ),
                  child: Text('+ ${s.troncAmount.toStringAsFixed(2)} €',
                      style: const TextStyle(
                          color: _emerald, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
      ],
    );
  }

  static String _fmtDate(Session s) {
    final dt = s.dateTime;
    if (dt == null) return '—';
    return DateFormat('d MMM y', 'fr_FR').format(dt);
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final num value;
  final String hint;
  final Color color;
  const _Counter({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 10, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text('${value.toStringAsFixed(0)} €',
                    style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrColors.muted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  final String label;
  final num amount;
  final bool paid;
  final VoidCallback? onTap;
  const _DueChip({
    required this.label,
    required this.amount,
    required this.paid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = paid ? _emerald : _rose;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(paid ? Icons.check_circle : Icons.cancel,
                size: 15, color: color),
            const SizedBox(width: 5),
            Text('$label : $amount €',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
