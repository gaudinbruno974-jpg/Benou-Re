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

class _CotisationsTab extends StatefulWidget {
  final List<Member> members;
  final bool canEdit;
  const _CotisationsTab({required this.members, required this.canEdit});

  @override
  State<_CotisationsTab> createState() => _CotisationsTabState();
}

class _CotisationsTabState extends State<_CotisationsTab> {
  int? _selectedYear;
  bool _unpaidOnly = false;

  /// Montant restant dû par [m] pour [year] (0 si tout est réglé).
  num _amountDue(Member m, int year) {
    final d = m.duesFor(year);
    num due = 0;
    if (!d.lodgeDuesPaid) due += d.lodgeDues;
    if (!d.orderDuesPaid) due += d.orderDues;
    if (d.elevationDues > 0 && !d.elevationDuesPaid) due += d.elevationDues;
    return due;
  }

  /// Ensemble des années disponibles (toutes celles enregistrées chez les
  /// membres + l'année courante), triées de la plus récente à la plus ancienne.
  List<int> get _availableYears {
    final years = <int>{DateTime.now().year};
    for (final m in widget.members) {
      years.addAll(m.duesByYear.keys);
    }
    final list = years.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  int get _year {
    final years = _availableYears;
    if (_selectedYear != null && years.contains(_selectedYear)) {
      return _selectedYear!;
    }
    final now = DateTime.now().year;
    return years.contains(now) ? now : years.first;
  }

  Future<void> _createNextYear() async {
    final years = _availableYears;
    final latest = years.first;
    final target = latest + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: Text('Nouvelle année : $target',
            style: const TextStyle(color: BrColors.goldBright)),
        content: Text(
          'Créer les cotisations $target en reprenant les montants de $latest '
          '(tous marqués non-payés). Les années déjà enregistrées ne sont pas '
          'modifiées. Vous pourrez ensuite ajuster les montants et pointer les '
          'paiements.',
          style: const TextStyle(color: BrColors.muted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: BrColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrColors.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final state = context.read<AppState>();
    for (final m in widget.members) {
      if (m.duesByYear.containsKey(target)) continue;
      final previous = m.duesFor(latest);
      await state.updateMember(m.withDuesForYear(target, previous.resetPaid()));
    }
    if (mounted) setState(() => _selectedYear = target);
  }

  Future<void> _editAmounts(Member m) async {
    final year = _year;
    final dues = m.duesFor(year);
    final lodgeCtrl =
        TextEditingController(text: '${dues.lodgeDues}');
    final orderCtrl =
        TextEditingController(text: '${dues.orderDues}');
    final elevationCtrl =
        TextEditingController(text: '${dues.elevationDues}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: Text('Montants $year — ${m.fullName}',
            style: const TextStyle(color: BrColors.goldBright, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _amountField(lodgeCtrl, 'Cotisation Loge (€)'),
            const SizedBox(height: 12),
            _amountField(orderCtrl, 'Cotisation Ordre (€)'),
            const SizedBox(height: 12),
            _amountField(elevationCtrl, 'Cotisation Grades / élévation (€)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: BrColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrColors.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final state = context.read<AppState>();
      final updated = dues.copyWith(
        lodgeDues: num.tryParse(lodgeCtrl.text) ?? dues.lodgeDues,
        orderDues: num.tryParse(orderCtrl.text) ?? dues.orderDues,
        elevationDues: num.tryParse(elevationCtrl.text) ?? dues.elevationDues,
      );
      await state.updateMember(m.withDuesForYear(year, updated));
    }
    lodgeCtrl.dispose();
    orderCtrl.dispose();
    elevationCtrl.dispose();
  }

  Widget _amountField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: BrColors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BrColors.muted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final members = widget.members;
    final canEdit = widget.canEdit;
    final year = _year;

    final unpaidMembers =
        members.where((m) => _amountDue(m, year) > 0).toList();
    final visibleMembers = _unpaidOnly ? unpaidMembers : members;

    num collected = 0;
    num pending = 0;
    for (final m in members) {
      final d = m.duesFor(year);
      d.lodgeDuesPaid ? collected += d.lodgeDues : pending += d.lodgeDues;
      d.orderDuesPaid ? collected += d.orderDues : pending += d.orderDues;
      if (d.elevationDues > 0) {
        d.elevationDuesPaid
            ? collected += d.elevationDues
            : pending += d.elevationDues;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _YearSelector(
                year: year,
                years: _availableYears,
                onChanged: (y) => setState(() => _selectedYear = y),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(width: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: BrColors.gold,
                    foregroundColor: Colors.black),
                onPressed: _createNextYear,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle année'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              selected: _unpaidOnly,
              onSelected: (v) => setState(() => _unpaidOnly = v),
              label: Text('Impayés uniquement (${unpaidMembers.length})'),
              avatar: Icon(
                _unpaidOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 18,
                color: _unpaidOnly ? Colors.black : BrColors.gold,
              ),
              labelStyle: TextStyle(
                  color: _unpaidOnly ? Colors.black : BrColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
              backgroundColor: BrColors.gold.withValues(alpha: 0.08),
              selectedColor: BrColors.gold,
              checkmarkColor: Colors.black,
              side: BorderSide(color: BrColors.gold.withValues(alpha: 0.4)),
            ),
            if (_unpaidOnly && unpaidMembers.isNotEmpty)
              Chip(
                label: Text(
                    'Reste à percevoir : ${pending.toStringAsFixed(0)} €'),
                labelStyle: const TextStyle(
                    color: _rose, fontSize: 12, fontWeight: FontWeight.bold),
                backgroundColor: _rose.withValues(alpha: 0.1),
                side: BorderSide(color: _rose.withValues(alpha: 0.4)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
            _unpaidOnly
                ? 'MEMBRES AVEC COTISATIONS IMPAYÉES $year (${unpaidMembers.length})'
                : 'DÉTAIL DES COMPTES INDIVIDUELS $year (${members.length})',
            style: const TextStyle(
                color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
        const SizedBox(height: 12),
        if (visibleMembers.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _emerald.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 32, color: _emerald),
                const SizedBox(height: 8),
                Text(
                  _unpaidOnly
                      ? 'Tous les membres sont à jour pour l\'année $year.'
                      : 'Aucun membre enregistré.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _emerald, fontSize: 13),
                ),
              ],
            ),
          ),
        for (final m in visibleMembers)
          Builder(builder: (context) {
            final d = m.duesFor(year);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
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
                                style: const TextStyle(
                                    color: BrColors.muted, fontSize: 12),
                              ),
                              if (_unpaidOnly)
                                Text(
                                  'Reste dû : ${_amountDue(m, year).toStringAsFixed(0)} €',
                                  style: const TextStyle(
                                      color: _rose,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        if (canEdit)
                          IconButton(
                            tooltip: 'Modifier les montants $year',
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: BrColors.muted),
                            onPressed: () => _editAmounts(m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DueChip(
                          label: 'LOGE',
                          amount: d.lodgeDues,
                          paid: d.lodgeDuesPaid,
                          onTap: canEdit
                              ? () => state.updateMember(m.withDuesForYear(
                                  year,
                                  d.copyWith(
                                      lodgeDuesPaid: !d.lodgeDuesPaid)))
                              : null,
                        ),
                        _DueChip(
                          label: 'ORDRE',
                          amount: d.orderDues,
                          paid: d.orderDuesPaid,
                          onTap: canEdit
                              ? () => state.updateMember(m.withDuesForYear(
                                  year,
                                  d.copyWith(
                                      orderDuesPaid: !d.orderDuesPaid)))
                              : null,
                        ),
                        if (d.elevationDues > 0)
                          _DueChip(
                            label: 'GRADES',
                            amount: d.elevationDues,
                            paid: d.elevationDuesPaid,
                            onTap: canEdit
                                ? () => state.updateMember(m.withDuesForYear(
                                    year,
                                    d.copyWith(
                                        elevationDuesPaid:
                                            !d.elevationDuesPaid)))
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _YearSelector extends StatelessWidget {
  final int year;
  final List<int> years;
  final ValueChanged<int> onChanged;
  const _YearSelector(
      {required this.year, required this.years, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BrColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: BrColors.gold),
          const SizedBox(width: 8),
          const Text('Année',
              style: TextStyle(color: BrColors.muted, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: year,
                dropdownColor: BrColors.surface,
                style: const TextStyle(
                    color: BrColors.goldBright,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
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
