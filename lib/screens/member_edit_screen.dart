// Création / édition d'un membre.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class MemberEditScreen extends StatefulWidget {
  final Member? member;
  const MemberEditScreen({super.key, this.member});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls;
  late String _grade;
  late String _status;
  bool _saving = false;

  static const _grades = ['Apprenti', 'Compagnon', 'Maitre'];
  static const _statuses = [
    'Actif',
    'Honoraire',
    'En sommeil',
    'Démissionnaire',
    'Radié'
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _ctrls = {
      'firstName': TextEditingController(text: m?.firstName ?? ''),
      'lastName': TextEditingController(text: m?.lastName ?? ''),
      'email': TextEditingController(text: m?.email ?? ''),
      'phone': TextEditingController(text: m?.phone ?? ''),
      'address': TextEditingController(text: m?.address ?? ''),
      'matricule': TextEditingController(text: m?.matricule ?? ''),
      'function': TextEditingController(text: m?.function ?? 'Aucun'),
      'motherLodge': TextEditingController(text: m?.motherLodge ?? ''),
      'sponsor': TextEditingController(text: m?.sponsor ?? ''),
      'lodgeDues': TextEditingController(text: '${m?.lodgeDues ?? 0}'),
      'orderDues': TextEditingController(text: '${m?.orderDues ?? 0}'),
    };
    _grade = m?.grade ?? 'Apprenti';
    _status = m?.status ?? 'Actif';
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final existing = widget.member;
    final id = existing?.id ??
        'm_${DateTime.now().millisecondsSinceEpoch}';
    final base = existing ?? Member(id: id);
    final lodgeDues = num.tryParse(_ctrls['lodgeDues']!.text) ?? 0;
    final orderDues = num.tryParse(_ctrls['orderDues']!.text) ?? 0;
    // Les montants saisis ici concernent l'année courante.
    final year = DateTime.now().year;
    final currentDues = base.duesFor(year).copyWith(
          lodgeDues: lodgeDues,
          orderDues: orderDues,
        );
    final member = base
        .copyWith(
          firstName: _ctrls['firstName']!.text.trim(),
          lastName: _ctrls['lastName']!.text.trim(),
          email: _ctrls['email']!.text.trim(),
          phone: _ctrls['phone']!.text.trim(),
          address: _ctrls['address']!.text.trim(),
          matricule: _ctrls['matricule']!.text.trim(),
          function: _ctrls['function']!.text.trim(),
          motherLodge: _ctrls['motherLodge']!.text.trim(),
          sponsor: _ctrls['sponsor']!.text.trim(),
          grade: _grade,
          status: _status,
          lodgeDues: lodgeDues,
          orderDues: orderDues,
        )
        .withDuesForYear(year, currentDues);
    try {
      if (existing == null) {
        await state.addMember(member);
      } else {
        await state.updateMember(member);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.member == null;
    return Scaffold(
      appBar: AppBar(
          title: Text(isNew ? 'Nouveau membre' : 'Modifier le membre')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const BrSectionTitle('IDENTITÉ', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('firstName', 'Prénom', required: true),
                  _field('lastName', 'Nom', required: true),
                  _field('email', 'Email',
                      keyboard: TextInputType.emailAddress),
                  _field('phone', 'Téléphone', keyboard: TextInputType.phone),
                  _field('address', 'Adresse', last: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const BrSectionTitle('PARCOURS MAÇONNIQUE',
                icon: Icons.auto_awesome),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('matricule', 'Matricule'),
                  _field('function', 'Office / Fonction'),
                  _field('motherLodge', 'Loge mère'),
                  _field('sponsor', 'Parrain', last: true),
                  const SizedBox(height: 14),
                  _dropdown('Grade', _grade, _grades,
                      (v) => setState(() => _grade = v)),
                  const SizedBox(height: 14),
                  _dropdown('Statut', _status, _statuses,
                      (v) => setState(() => _status = v)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const BrSectionTitle('COTISATIONS',
                icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('lodgeDues', 'Cotisation Loge (€)',
                      keyboard: TextInputType.number),
                  _field('orderDues', 'Cotisation Ordre (€)',
                      keyboard: TextInputType.number, last: true),
                ],
              ),
            ),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BrColors.text))
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label,
      {bool required = false, TextInputType? keyboard, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: _ctrls[key],
        keyboardType: keyboard,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
            : null,
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: BrColors.surface,
          style: const TextStyle(color: BrColors.text),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}
