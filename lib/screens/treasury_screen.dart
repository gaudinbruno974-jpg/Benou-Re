// Trésorerie — parité avec src/components/TreasuryScreen.tsx.
// Deux onglets : Cotisations (Loge / Ordre / Grades, encaissé vs à percevoir)
// et Tronc de la Veuve (total récolté + historique des tenues).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../services/drive_service.dart';
import '../services/email_link.dart';
import '../services/pdf_service.dart';
import '../services/treasury_document_service.dart';
import '../services/url_opener.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

const _emerald = Color(0xFF34D399);
const _rose = Color(0xFFFB7185);

class TreasuryScreen extends StatelessWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canEdit = canEditTreasury(state.currentUser);
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
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  /// Montant restant dû par [m] pour [year] (0 si exonéré ou tout est réglé).
  num _amountDue(Member m, int year) {
    if (m.isExemptFromDues) return 0;
    return m.duesFor(year).totalPending;
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

  /// Saisie d'un versement partiel sur une ligne de cotisation.
  Future<void> _editPayment(
    Member m,
    String label,
    num dues,
    num paidAmount,
  ) async {
    final year = _year;
    final ctrl = TextEditingController(
        text: paidAmount > 0 ? _trim(paidAmount) : '');

    final result = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: Text('$label $year — ${m.fullName}',
            style: const TextStyle(color: BrColors.goldBright, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant dû : ${_trim(dues)} €',
                style: const TextStyle(color: BrColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            _amountField(ctrl, 'Montant versé (€)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: BrColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, dues),
            child: const Text('Solder',
                style: TextStyle(color: _emerald)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BrColors.gold),
            onPressed: () => Navigator.pop(
                ctx, num.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (result == null || !mounted) return;
    final state = context.read<AppState>();
    final dy = m.duesFor(year);
    final amount = result < 0 ? 0 : result;
    final updated = switch (label) {
      'LOGE' => dy.copyWith(lodgeDuesPaidAmount: amount, lodgeDuesPaid: false),
      'ORDRE' => dy.copyWith(orderDuesPaidAmount: amount, orderDuesPaid: false),
      _ => dy.copyWith(
          elevationDuesPaidAmount: amount, elevationDuesPaid: false),
    };
    var synced = updated.syncPaidFlags();
    // Date de règlement (utilisée sur le Quitus) : fixée à aujourd'hui dès
    // que la ligne devient soldée, effacée si elle redevient partielle.
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    if (label == 'LOGE') {
      synced = synced.copyWith(
          lodgeDuesPaidDate: synced.lodgeDuesPaid ? today : '');
    } else if (label == 'ORDRE') {
      synced = synced.copyWith(
          orderDuesPaidDate: synced.orderDuesPaid ? today : '');
    }
    await state.updateMember(m.withDuesForYear(year, synced));
  }

  /// Bascule « soldé / non soldé » en remettant le versement à zéro ou au dû.
  /// La date de règlement (utilisée sur le Quitus) est fixée à aujourd'hui à
  /// ce moment, et effacée si la ligne redevient non soldée.
  DuesYear _toggleLine(DuesYear d, String label) {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    switch (label) {
      case 'LOGE':
        final paid = !d.lodgeDuesPaid;
        return d.copyWith(
            lodgeDuesPaid: paid,
            lodgeDuesPaidAmount: paid ? d.lodgeDues : 0,
            lodgeDuesPaidDate: paid ? today : '');
      case 'ORDRE':
        final paid = !d.orderDuesPaid;
        return d.copyWith(
            orderDuesPaid: paid,
            orderDuesPaidAmount: paid ? d.orderDues : 0,
            orderDuesPaidDate: paid ? today : '');
      default:
        final paid = !d.elevationDuesPaid;
        return d.copyWith(
            elevationDuesPaid: paid,
            elevationDuesPaidAmount: paid ? d.elevationDues : 0);
    }
  }

  Future<void> _exportPdf(List<Member> members) async {
    final year = _year;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await buildTreasuryReportPdf(year, members);
      await Printing.layoutPdf(
        onLayout: (_) async => Uint8List.fromList(bytes),
        name: 'bilan_cotisations_$year.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    }
  }

  /// Génère l'Appel de cotisation ou le Quitus de [m] pour l'année en cours,
  /// l'archive sur Drive, puis envoie directement l'e-mail avec le PDF en
  /// pièce jointe réelle (API Gmail — un simple lien mailto/Gmail-compose ne
  /// permet aucune pièce jointe). Si l'envoi échoue (permission Gmail
  /// refusée...), on se rabat sur l'ancien lien de composition sans pièce
  /// jointe plutôt que de bloquer l'envoi.
  Future<void> _sendDocument(Member m, {required bool isQuitus}) async {
    final state = context.read<AppState>();
    final year = _year;
    final messenger = ScaffoldMessenger.of(context);
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(
        isQuitus
            ? await buildQuitusPdf(m, year, widget.members,
                lodgeVmName: state.lodgeVmName)
            : await buildCapitationCallPdf(m, year, widget.members,
                lodgeVmName: state.lodgeVmName),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur de génération : $e')));
      return;
    }

    try {
      await DriveService.instance.archiveTreasuryDocument(
        type: isQuitus ? 'Quitus' : 'Capitations',
        year: year,
        fileName: isQuitus
            ? quitusFileName(m, year)
            : capitationCallFileName(m, year),
        bytes: bytes,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Archivage Drive : $e')));
    }

    if (!mounted) return;
    final subject = isQuitus ? quitusSubject(year) : capitationCallSubject(year);
    final body = isQuitus
        ? quitusBody(m, year, widget.members, lodgeVmName: state.lodgeVmName)
        : capitationCallBody(m, year, widget.members,
            lodgeVmName: state.lodgeVmName);
    final to = m.email.trim();
    if (to.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ce membre n\'a pas d\'e-mail renseigné.')),
      );
      return;
    }
    final attachmentName = isQuitus
        ? quitusFileName(m, year)
        : capitationCallFileName(m, year);

    try {
      await DriveService.instance.sendGmailWithAttachment(
        to: to,
        subject: subject,
        body: body,
        attachmentName: attachmentName,
        attachmentBytes: bytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('E-mail envoyé, avec le PDF en pièce jointe.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Envoi Gmail impossible ($e) — ouverture sans pièce jointe.')),
      );
      if (!mounted) return;
      await openExternalUrl(emailComposeUrl(to: to, subject: subject, body: body));
    }

    if (!mounted) return;
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final dy = m.duesFor(year);
    final updated = isQuitus
        ? dy.copyWith(quitusSent: true, quitusSentDate: today)
        : dy.copyWith(appelSent: true, appelSentDate: today);
    await state.updateMember(m.withDuesForYear(year, updated));
  }

  static String _trim(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

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
      if (m.isExemptFromDues) continue;
      final d = m.duesFor(year);
      collected += d.totalCollected;
      pending += d.totalPending;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
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
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Exporter le bilan $year en PDF',
                onPressed: () => _exportPdf(members),
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: BrColors.gold),
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
        const SizedBox(height: 24),
        BrSectionTitle(
            _unpaidOnly
                ? 'MEMBRES AVEC COTISATIONS IMPAYÉES $year (${unpaidMembers.length})'
                : 'DÉTAIL DES COMPTES INDIVIDUELS $year (${members.length})',
            icon: Icons.receipt_long_outlined),
        const SizedBox(height: 16),
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrCard(
                accent: _amountDue(m, year) > 0 ? _rose : _emerald,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BrAvatar(
                          firstName: m.firstName,
                          lastName: m.lastName,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.fullName.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.4)),
                              const SizedBox(height: 4),
                              Text(
                                '${m.grade} • ${m.function != 'Aucun' ? m.function : 'Membre'}',
                                style: const TextStyle(
                                    color: BrColors.muted, fontSize: 12),
                              ),
                              if (m.isExemptFromDues)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: BrBadge(
                                    label: 'Exonéré • ${m.status}',
                                    color: _emerald,
                                    icon: Icons.verified_outlined,
                                  ),
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
                        if (canEdit && !m.isExemptFromDues)
                          IconButton(
                            tooltip: 'Modifier les montants $year',
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: BrColors.muted),
                            onPressed: () => _editAmounts(m),
                          ),
                        if (canEdit && !m.isExemptFromDues)
                          PopupMenuButton<bool>(
                            tooltip: 'Envoyer un document',
                            icon: const Icon(Icons.mail_outline,
                                size: 18, color: BrColors.muted),
                            onSelected: (isQuitus) =>
                                _sendDocument(m, isQuitus: isQuitus),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: false,
                                child: Text('Envoyer l\'Appel de cotisation'),
                              ),
                              PopupMenuItem(
                                value: true,
                                enabled: d.fullyPaid,
                                child: Text(
                                  d.fullyPaid
                                      ? 'Envoyer le Quitus'
                                      : 'Envoyer le Quitus (Loge et Ordre '
                                          'pas encore soldés)',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (m.isExemptFromDues)
                      const Text(
                        'Membre exonéré : ses cotisations ne sont pas comptées '
                        'dans les totaux.',
                        style:
                            TextStyle(color: BrColors.muted, fontSize: 12),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _DueChip(
                            label: 'LOGE',
                            amount: d.lodgeDues,
                            paidAmount: d.lodgeCollected,
                            paid: d.lodgeDuesPaid,
                            onTap: canEdit
                                ? () => state.updateMember(m.withDuesForYear(
                                    year, _toggleLine(d, 'LOGE')))
                                : null,
                            onLongPress: canEdit
                                ? () => _editPayment(m, 'LOGE', d.lodgeDues,
                                    d.lodgeCollected)
                                : null,
                          ),
                          _DueChip(
                            label: 'ORDRE',
                            amount: d.orderDues,
                            paidAmount: d.orderCollected,
                            paid: d.orderDuesPaid,
                            onTap: canEdit
                                ? () => state.updateMember(m.withDuesForYear(
                                    year, _toggleLine(d, 'ORDRE')))
                                : null,
                            onLongPress: canEdit
                                ? () => _editPayment(m, 'ORDRE', d.orderDues,
                                    d.orderCollected)
                                : null,
                          ),
                          if (d.elevationDues > 0)
                            _DueChip(
                              label: 'GRADES',
                              amount: d.elevationDues,
                              paidAmount: d.elevationCollected,
                              paid: d.elevationDuesPaid,
                              onTap: canEdit
                                  ? () => state.updateMember(m.withDuesForYear(
                                      year, _toggleLine(d, 'GRADES')))
                                  : null,
                              onLongPress: canEdit
                                  ? () => _editPayment(m, 'GRADES',
                                      d.elevationDues, d.elevationCollected)
                                  : null,
                            ),
                        ],
                      ),
                    if (!m.isExemptFromDues &&
                        (d.appelSent || d.quitusSent)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (d.appelSent)
                            Text(
                              'Appel envoyé le ${d.appelSentDate}',
                              style: const TextStyle(
                                  color: BrColors.muted, fontSize: 11),
                            ),
                          if (d.quitusSent)
                            Text(
                              'Quitus envoyé le ${d.quitusSentDate}',
                              style: const TextStyle(
                                  color: BrColors.muted, fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                    if (canEdit && !m.isExemptFromDues) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Appui long sur une cotisation : saisir un versement '
                        'partiel.',
                        style: TextStyle(color: BrColors.muted, fontSize: 10),
                      ),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: BrColors.backgroundDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(BrColors.radiusS),
        border: Border.all(color: BrColors.gold.withValues(alpha: 0.35)),
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
    // Toutes les tenues sont agrégées, y compris celles dont le tronc a été
    // saisi depuis l'éditeur de planche tracée.
    final withTronc = sessions.where((s) => s.troncAmount > 0).toList()
      ..sort((a, b) {
        final da = a.dateTime;
        final db = b.dateTime;
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
    final total = sessions.fold<num>(0, (acc, s) => acc + s.troncAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        BrCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  height: 66,
                  width: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BrColors.gold.withValues(alpha: 0.14),
                    border: Border.all(
                        color: BrColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      size: 32, color: BrColors.goldBright),
                ),
                const SizedBox(height: 14),
                const Text('CAISSE GÉNÉRALE DU TRONC',
                    style: TextStyle(
                        color: BrColors.muted,
                        fontSize: 11,
                        letterSpacing: 2)),
                const SizedBox(height: 4),
                Text('${total.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        color: BrColors.goldBright,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Fonds dédiés aux œuvres de bienfaisance et à l'aide aux veuves et orphelins de l'atelier.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: BrColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
        ),
        const SizedBox(height: 26),
        BrSectionTitle('HISTORIQUE DES TENUES (${withTronc.length})',
            icon: Icons.history),
        const SizedBox(height: 16),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BrCard(
                accent: _emerald,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title.isNotEmpty
                                ? s.title
                                : 'Tenue au ${s.degreeLabel}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Grade : ${s.degreeLabel} • ${_fmtDate(s)}',
                            style: const TextStyle(
                                color: BrColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: _emerald.withValues(alpha: 0.45)),
                      ),
                      child: Text('+ ${s.troncAmount.toStringAsFixed(2)} €',
                          style: const TextStyle(
                              color: _emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ],
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
      child: BrCard(
        accent: color,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              FittedBox(
                child: Text('${value.toStringAsFixed(0)} €',
                    style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrColors.muted, fontSize: 10)),
            ],
          ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  final String label;
  final num amount;
  final num paidAmount;
  final bool paid;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _DueChip({
    required this.label,
    required this.amount,
    required this.paidAmount,
    required this.paid,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final partial = !paid && paidAmount > 0;
    final color = paid
        ? _emerald
        : partial
            ? BrColors.gold
            : _rose;
    final text = paid
        ? '$label : $amount €'
        : '$label : ${paidAmount % 1 == 0 ? paidAmount.toStringAsFixed(0) : paidAmount} € / $amount €';
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                paid
                    ? Icons.check_circle
                    : partial
                        ? Icons.timelapse
                        : Icons.cancel,
                size: 15,
                color: color),
            const SizedBox(width: 5),
            Text(text,
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
