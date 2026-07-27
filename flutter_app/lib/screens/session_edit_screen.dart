// Création / modification d'une tenue (porté depuis src/components/SessionsList.tsx).
// Champs principaux + sélection des présents, excusés et visiteurs, puis
// enregistrement dans Firestore via AppState. Les champs non modélisés
// explicitement (typeTenue, degreTravail, travail1..4, ligneCloture...) sont
// écrits dans la map brute pour rester compatibles avec le web.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _sessionTypes = [
  'Ordinaire',
  'Solennelle',
  'Blanche',
  'Funèbre',
  'Installation',
];
const _degrees = ['Apprenti', 'Compagnon', 'Maitre'];

class SessionEditScreen extends StatefulWidget {
  final Session? session;
  const SessionEditScreen({super.key, this.session});

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _sessionNumber;
  late final TextEditingController _location;
  late final TextEditingController _closingTime;
  late final TextEditingController _tronc;
  late final TextEditingController _vmName;
  late final TextEditingController _t1;
  late final TextEditingController _t2;
  late final TextEditingController _t3;
  late final TextEditingController _t4;
  late final TextEditingController _cloture;

  late String _type;
  late String _degree;
  DateTime? _date;
  late bool _hasAgape;

  late List<String> _presentIds;
  late List<String> _excusedIds;
  late List<String> _visitorIds;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _title = TextEditingController(text: s?.title ?? '');
    _sessionNumber = TextEditingController(text: s?.sessionNumber ?? '');
    _location = TextEditingController(
        text: s?.location.isNotEmpty == true
            ? s!.location
            : (s?.lieuReunion ?? 'Temple Thérèse Eliseman à Saint-Pierre'));
    _closingTime = TextEditingController(text: s?.closingTime ?? '18:30');
    _tronc = TextEditingController(
        text: s != null && s.troncAmount != 0 ? '${s.troncAmount}' : '');
    _vmName = TextEditingController(text: s?.vmName ?? '');
    _t1 = TextEditingController(text: s?.travail1 ?? '');
    _t2 = TextEditingController(text: s?.travail2 ?? '');
    _t3 = TextEditingController(text: s?.travail3 ?? '');
    _t4 = TextEditingController(text: s?.travail4 ?? '');
    _cloture = TextEditingController(text: s?.ligneCloture ?? '');

    _type = _sessionTypes.contains(s?.typeTenue)
        ? s!.typeTenue!
        : (_sessionTypes.contains(s?.type) ? s!.type : 'Ordinaire');
    _degree = _degrees.contains(s?.degreTravail)
        ? s!.degreTravail!
        : (_degrees.contains(s?.degree) ? s!.degree : 'Apprenti');
    _date = s?.dateTime;
    _hasAgape = s?.hasAgape ?? false;
    _presentIds = List<String>.from(s?.presentIds ?? const []);
    _excusedIds = List<String>.from(s?.excusedIds ?? const []);
    _visitorIds = List<String>.from(s?.visitorIds ?? const []);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _sessionNumber,
      _location,
      _closingTime,
      _tronc,
      _vmName,
      _t1,
      _t2,
      _t3,
      _t4,
      _cloture,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date.')),
      );
      return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final existing = widget.session;
    final id = existing?.id ?? 's_${DateTime.now().millisecondsSinceEpoch}';
    final iso = DateFormat('yyyy-MM-dd').format(_date!);

    final map = <String, dynamic>{
      if (existing != null) ...existing.toMap(),
      'id': id,
      'title': _title.text.trim(),
      'date': iso,
      'dateReprise': iso,
      'type': _type,
      'typeTenue': _type,
      'degree': _degree,
      'degreTravail': _degree,
      'location': _location.text.trim(),
      'lieuReunion': _location.text.trim(),
      'sessionNumber': _sessionNumber.text.trim(),
      'closingTime': _closingTime.text.trim(),
      'troncAmount': num.tryParse(_tronc.text.trim().replaceAll(',', '.')) ?? 0,
      'vmName': _vmName.text.trim(),
      'travail1': _t1.text.trim(),
      'travail2': _t2.text.trim(),
      'travail3': _t3.text.trim(),
      'travail4': _t4.text.trim(),
      'ligneCloture': _cloture.text.trim(),
      'hasAgape': _hasAgape,
      'presentIds': _presentIds,
      'excusedIds': _excusedIds,
      'visitorIds': _visitorIds,
    };

    final chrono = int.tryParse(
        _sessionNumber.text.trim().replaceAll(RegExp(r'[^\d]'), ''));
    if (chrono != null) map['chrono'] = chrono;

    try {
      final session = Session.fromMap(id, map);
      if (existing == null) {
        await state.addSession(session);
      } else {
        await state.updateSession(session);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur enregistrement : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isNew = widget.session == null;

    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'Nouvelle tenue' : 'Modifier la tenue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_title, 'Titre / objet'),
            _dateField(),
            _dropdown('Type de tenue', _type, _sessionTypes,
                (v) => setState(() => _type = v)),
            _dropdown('Degré', _degree, _degrees,
                (v) => setState(() => _degree = v)),
            _field(_location, 'Lieu'),
            _field(_sessionNumber, 'Numéro de tenue',
                keyboard: TextInputType.number),
            _field(_closingTime, 'Heure de clôture'),
            _field(_tronc, 'Tronc de la Veuve (€)',
                keyboard: const TextInputType.numberWithOptions(decimal: true)),
            _field(_vmName, 'Vénérable Maître'),
            const SizedBox(height: 8),
            const _Heading("Ordre du jour"),
            _field(_t1, 'Travail 1'),
            _field(_t2, 'Travail 2'),
            _field(_t3, 'Travail 3'),
            _field(_t4, 'Travail 4'),
            _field(_cloture, 'Ligne de clôture'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Suivi d\'agapes',
                  style: TextStyle(color: BrColors.text)),
              activeThumbColor: BrColors.gold,
              value: _hasAgape,
              onChanged: (v) => setState(() => _hasAgape = v),
            ),
            const SizedBox(height: 8),
            _MultiSelect(
              label: 'Membres présents',
              options: [
                for (final m in state.members) (m.id, m.fullName),
              ],
              selected: _presentIds,
              onChanged: (ids) => setState(() {
                _presentIds = ids;
                _excusedIds =
                    _excusedIds.where((e) => !ids.contains(e)).toList();
              }),
            ),
            _MultiSelect(
              label: 'Membres excusés',
              options: [
                for (final m in state.members) (m.id, m.fullName),
              ],
              selected: _excusedIds,
              onChanged: (ids) => setState(() {
                _excusedIds = ids;
                _presentIds =
                    _presentIds.where((e) => !ids.contains(e)).toList();
              }),
            ),
            _MultiSelect(
              label: 'Visiteurs',
              options: [
                for (final v in state.visitors)
                  (v.id, '${v.fullName} — ${v.lodge}'),
              ],
              selected: _visitorIds,
              onChanged: (ids) => setState(() => _visitorIds = ids),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BrColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: _date ?? now,
            firstDate: DateTime(now.year - 3),
            lastDate: DateTime(now.year + 3),
            locale: const Locale('fr', 'FR'),
          );
          if (picked != null) setState(() => _date = picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Date de la tenue'),
          child: Text(
            _date == null
                ? 'Choisir une date'
                : DateFormat('EEEE d MMMM y', 'fr_FR').format(_date!),
            style: TextStyle(
                color: _date == null ? BrColors.muted : BrColors.text),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: BrColors.surface,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
        items: [
          for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(text,
            style: const TextStyle(
                color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
      );
}

class _MultiSelect extends StatelessWidget {
  final String label;
  final List<(String, String)> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelect({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label (${selected.length})',
              style: const TextStyle(
                  color: BrColors.gold, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (options.isEmpty)
            const Text('Aucun disponible',
                style: TextStyle(color: BrColors.muted, fontSize: 13))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final o in options)
                  FilterChip(
                    label: Text(o.$2),
                    selected: selected.contains(o.$1),
                    showCheckmark: false,
                    backgroundColor: BrColors.surface,
                    selectedColor: BrColors.teal,
                    labelStyle: TextStyle(
                      color: selected.contains(o.$1)
                          ? Colors.white
                          : BrColors.muted,
                      fontSize: 12,
                    ),
                    onSelected: (sel) {
                      final next = List<String>.from(selected);
                      if (sel) {
                        next.add(o.$1);
                      } else {
                        next.remove(o.$1);
                      }
                      onChanged(next);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
