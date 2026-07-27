// Trésorerie : cotisations (porté partiellement depuis src/components/TreasuryScreen.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

class TreasuryScreen extends StatelessWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final members = [...state.members]
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    num totalDue = 0;
    num totalPaid = 0;
    for (final m in members) {
      final due = m.lodgeDues + m.orderDues + m.elevationDues;
      totalDue += due;
      if (m.lodgeDuesPaid) totalPaid += m.lodgeDues;
      if (m.orderDuesPaid) totalPaid += m.orderDues;
      if (m.elevationDuesPaid) totalPaid += m.elevationDues;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trésorerie')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _StatCard(
                  label: 'Cotisations dues',
                  value: '$totalDue €',
                  color: BrColors.gold),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Encaissé',
                  value: '$totalPaid €',
                  color: const Color(0xFF34D399)),
              const SizedBox(width: 12),
              _StatCard(
                  label: 'Reste à percevoir',
                  value: '${totalDue - totalPaid} €',
                  color: const Color(0xFFFB7185)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('DÉTAIL PAR MEMBRE',
              style: TextStyle(
                  color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 12),
          for (final m in members)
            Card(
              child: ListTile(
                title: Text(m.fullName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'Loge: ${m.lodgeDues}€ ${m.lodgeDuesPaid ? '✓' : '✗'}  •  Ordre: ${m.orderDues}€ ${m.orderDuesPaid ? '✓' : '✗'}',
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
                ),
                trailing: Switch(
                  value: m.lodgeDuesPaid,
                  activeThumbColor: BrColors.teal,
                  onChanged: (v) => state
                      .updateMember(m.copyWith(lodgeDuesPaid: v)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
