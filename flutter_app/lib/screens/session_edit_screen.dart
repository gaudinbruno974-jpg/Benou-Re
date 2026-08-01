// Création / modification d'une tenue — parité avec src/components/SessionsList.tsx.
//
// Reproduit la planification riche du web : type/degré, date & heure de reprise,
// heure de suspension, lieu, ordre du jour (4 travaux fixes auto-générés mais
// modifiables), ordres du jour complémentaires dynamiques, ligne de clôture
// numérotée automatiquement, et section Agapes (heure, type de repas, médaille).
// Le chrono est réservé auprès de config/settings à la création (comme React).
//
// À la création d'une tenue, on crée le dossier Google Drive, on y dépose la
// convocation PDF et on mémorise l'ID/URL du dossier dans la session. Cet
// archivage est « best effort » : son échec n'empêche pas l'enregistrement.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';

const _sessionTypes = [
  'Ordinaire',
  'Extraordinaire',
  'Banquet',
  'Tenue blanche',
  'Tenue noire',
];
const _degrees = ['Apprenti', 'Compagnon', 'Maître'];
const _repasTypes = ['Agape avec médaille', 'Agape partage', 'Agape offerte'];

// ─── Générateurs de textes (portés de SessionsList.tsx) ──────────────────
Map<String, String> _travauxFixes(String degre, TimeOfDay? heure) {
  final ord = Session.degreeOrdinal(degre);
  final h = heure != null
      ? '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}'
      : 'xxhxx';
  return {
    't1':
        '$h Ouverture des Travaux au $ord Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Bruno GAU∴',
    't2': 'Appel des FF∴ et SS∴ de la loge',
    't3':
        'Lecture de la planche tracée de nos derniers travaux au $ord Degré symbolique.',
    't4': 'Lecture de la correspondance et des affaires diverses.',
  };
}

String _ligneCloture(String degre, int ordresCount) {
  final ord = Session.degreeOrdinal(degre);
  final n = 4 + ordresCount + 1;
  return '$n. Clôture des Travaux au $ord Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Bruno GAU∴';
}

class SessionEditScreen extends StatefulWidget {
  final Session? session;
  const SessionEditScreen({super.key, this.session});

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _location;
  late final TextEditingController _tronc;
  late final TextEditingController _vmName;
  late final TextEditingController _t1;
  late final TextEditingController _t2;
  late final TextEditingController _t3;
  late final TextEditingController _t4;
  late final TextEditingController _cloture;
  late final TextEditingController _medaille;
  late final List<TextEditingController> _ordres;

  late String _type;
  late String _degree;
  DateTime? _date;
  TimeOfDay? _heureReprise;
  TimeOfDay? _heureSuspension;
  TimeOfDay? _heureAgape;
  bool _hasAgape = false;
  String? _typeRepas;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _location = TextEditingController(
      text: s?.location.isNotEmpty == true
          ? s!.location
          : (s?.lieuReunion ?? 'Temple Thérèse Eliseman à Saint-Pierre'),
    );
    _tronc = TextEditingController(
      text: s != null && s.troncAmount != 0 ? '${s.troncAmount}' : '',
    );
    _vmName = TextEditingController(text: s?.vmName ?? '');
    _t1 = TextEditingController(text: s?.travail1 ?? '');
    _t2 = TextEditingController(text: s?.travail2 ?? '');
    _t3 = TextEditingController(text: s?.travail3 ?? '');
    _t4 = TextEditingController(text: s?.travail4 ?? '');
    _cloture = TextEditingController(text: s?.ligneCloture ?? '');
    _medaille = TextEditingController(
      text: (s?.montantMedaille ?? 0) > 0 ? '${s!.montantMedaille}' : '',
    );

    final ordres = (s?.ordresJour ?? const <String>[])
        .where((o) => o.trim().isNotEmpty)
        .toList();
    _ordres = [
      for (final o in ordres) TextEditingController(text: o),
      if (ordres.isEmpty) TextEditingController(),
    ];

    _type = _ensure(s?.typeTenue ?? s?.type, 'Ordinaire');
    _degree = _ensure(
      _normalizeDegree(s?.degreTravail ?? s?.degree),
      'Apprenti',
    );
    _date = s?.dateTime;
    _heureReprise = _date != null && (_date!.hour != 0 || _date!.minute != 0)
        ? TimeOfDay(hour: _date!.hour, minute: _date!.minute)
        : null;
    _heureSuspension = _parseTime(s?.heureSuspension ?? s?.closingTime);
    _heureAgape = _parseTime(s?.heureAgape);
    _hasAgape = s?.suitAgapes ?? false;
    _typeRepas = _repasTypes.contains(s?.typeRepas) ? s!.typeRepas : null;
  }

  String _normalizeDegree(String? d) => d == 'Maitre' ? 'Maître' : (d ?? '');

  String _ensure(String? value, String fallback) {
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

  List<String> _itemsWith(List<String> base, String value) =>
      base.contains(value) ? base : [...base, value];

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(RegExp('[:h]'));
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    for (final c in [
      _location,
      _tronc,
      _vmName,
      _t1,
      _t2,
      _t3,
      _t4,
      _cloture,
      _medaille,
      ..._ordres,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _ordresCount => _ordres.where((c) => c.text.trim().isNotEmpty).length;

  void _regenerateTravaux() {
    final fixes = _travauxFixes(_degree, _heureReprise);
    _t1.text = fixes['t1']!;
    _t2.text = fixes['t2']!;
    _t3.text = fixes['t3']!;
    _t4.text = fixes['t4']!;
    _regenerateCloture();
  }

  void _regenerateCloture() {
    _cloture.text = _ligneCloture(_degree, _ordresCount);
  }

  // ─── ARCHIVAGE DRIVE À LA CRÉATION (best effort) ──────────────────
  Future<Session> _createDriveFolder(Session session, int chrono) async {
    final pdf = Uint8List.fromList(await buildConvocationPdf(session, chrono));
    final res = await DriveService.instance.ensureFolderAndUpload(
      session,
      {'Convocation_Tenue_$chrono.pdf': pdf},
    );
    final map = session.toMap();
    map['driveFolderId'] = res.folderId;
    map['driveFolderUrl'] = res.folderUrl;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dossier Drive créé par ${res.email}'),
          backgroundColor: BrColors.teal,
        ),
      );
    }
    return Session.fromMap(session.id, map);
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
    final dateOnly = DateFormat('yyyy-MM-dd').format(_date!);
    final dateReprise = _heureReprise != null
        ? '${dateOnly}T${_heureReprise!.hour.toString().padLeft(2, '0')}:${_heureReprise!.minute.toString().padLeft(2, '0')}'
        : dateOnly;
    final closing = _heureSuspension != null ? _fmtTime(_heureSuspension!) : '';
    final ordres = _ordres
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();

    final map = <String, dynamic>{
      if (existing != null) ...existing.toMap(),
      'id': id,
      'title': '',
      'date': dateOnly,
      'dateReprise': dateReprise,
      'type': _type,
      'typeTenue': _type,
      'degree': _degree,
      'degreTravail': _degree,
      'location': _location.text.trim(),
      'lieuReunion': _location.text.trim(),
      'closingTime': closing,
      'heureSuspension': closing,
      'troncAmount': num.tryParse(_tronc.text.trim().replaceAll(',', '.')) ?? 0,
      'vmName': _vmName.text.trim(),
      'travail1': _t1.text.trim(),
      'travail2': _t2.text.trim(),
      'travail3': _t3.text.trim(),
      'travail4': _t4.text.trim(),
      'ordresJour': ordres,
      'ligneCloture': _cloture.text.trim(),
      'hasAgape': _hasAgape,
      'suitAgapes': _hasAgape,
      'status': existing?.statut ?? 'Planifiée',
    };

    if (_hasAgape) {
      map['heureAgape'] = _heureAgape != null ? _fmtTime(_heureAgape!) : '';
      map['agapeTime'] = map['heureAgape'];
      map['typeRepas'] = _typeRepas ?? '';
      map['agapeType'] = _typeRepas ?? '';
      if (_typeRepas == 'Agape avec médaille') {
        map['montantMedaille'] =
            num.tryParse(_medaille.text.trim().replaceAll(',', '.')) ?? 0;
      } else {
        map.remove('montantMedaille');
      }
    } else {
      map.remove('heureAgape');
      map.remove('typeRepas');
      map.remove('montantMedaille');
      map['agapeType'] = '';
    }

    try {
      int? chrono = existing?.chrono?.toInt();
      if (existing == null) {
        chrono = await state.allocateSessionChrono();
      }
      if (chrono != null) {
        map['chrono'] = chrono;
        map['sessionNumber'] = '$chrono';
      }
      final session = Session.fromMap(id, map);
      if (existing == null) {
        await state.addSession(session);
        // Archivage Drive « best effort » : ne doit pas bloquer la création.
        if (chrono != null) {
          try {
            await state.updateSession(
                await _createDriveFolder(session, chrono));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dossier Drive non créé : $e'),
                  backgroundColor: BrColors.error,
                ),
              );
            }
          }
        }
      } else {
        await state.updateSession(session);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur enregistrement : $e')));
      }
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isNew = widget.session == null;
    final ord = Session.degreeOrdinal(_degree);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nouvelle tenue' : 'Modifier la tenue'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _dropdown(
              'Type de Tenue',
              _type,
              _itemsWith(_sessionTypes, _type),
              (v) => setState(() => _type = v),
            ),
            _dropdown(
              'Degré de Travail',
              _degree,
              _itemsWith(_degrees, _degree),
              (v) => setState(() {
                _degree = v;
                _regenerateTravaux();
              }),
              labelBuilder: (d) => '$d (${Session.degreeOrdinal(d)} Degré)',
            ),
            Row(
              children: [
                Expanded(child: _dateField()),
                const SizedBox(width: 8),
                Expanded(
                  child: _timeField(
                    'Heure de reprise',
                    _heureReprise,
                    (t) => setState(() {
                      _heureReprise = t;
                      _regenerateTravaux();
                    }),
                  ),
                ),
              ],
            ),
            _timeField(
              'Heure de suspension (clôture)',
              _heureSuspension,
              (t) => setState(() => _heureSuspension = t),
            ),
            _field(_location, 'Lieu de Réunion', icon: Icons.place_outlined),

            const SizedBox(height: 8),
            _Heading('ORDRE DU JOUR — TRAVAUX FIXES ($ord Degré)'),
            _numberedField('1', _t1),
            _numberedField('2', _t2),
            _numberedField('3', _t3),
            _numberedField('4', _t4),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'Tous les travaux peuvent être modifiés.',
                style: TextStyle(color: BrColors.muted, fontSize: 11),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _Heading('ORDRES DU JOUR COMPLÉMENTAIRES'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _ordres.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 16, color: BrColors.teal),
                  label: const Text(
                    'Ajouter',
                    style: TextStyle(color: BrColors.teal, fontSize: 12),
                  ),
                ),
              ],
            ),
            for (int i = 0; i < _ordres.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${5 + i}.',
                        style: const TextStyle(
                          color: BrColors.gold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ordres[i],
                        style: const TextStyle(color: BrColors.text),
                        decoration: const InputDecoration(
                          hintText: 'ex : Lecture de planche...',
                        ),
                        onChanged: (_) => setState(_regenerateCloture),
                      ),
                    ),
                    if (_ordres.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: BrColors.muted,
                        ),
                        onPressed: () => setState(() {
                          _ordres.removeAt(i).dispose();
                          _regenerateCloture();
                        }),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 8),
            _field(_cloture, 'Ligne de clôture'),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Numéro auto-généré : ${4 + _ordresCount + 1}° (texte modifiable).',
                style: const TextStyle(color: BrColors.muted, fontSize: 11),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: BrColors.gold),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Suit-elle d'Agapes fraternelles ?",
                style: TextStyle(color: BrColors.gold, letterSpacing: 1),
              ),
              activeThumbColor: BrColors.teal,
              value: _hasAgape,
              onChanged: (v) => setState(() {
                _hasAgape = v;
                if (!v) {
                  _typeRepas = null;
                  _heureAgape = null;
                }
              }),
            ),
            if (_hasAgape) ...[
              Row(
                children: [
                  Expanded(
                    child: _timeField(
                      "Heure de l'agape",
                      _heureAgape,
                      (t) => setState(() => _heureAgape = t),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown(
                      'Type de repas',
                      _typeRepas ?? '',
                      ['', ..._repasTypes],
                      (v) => setState(() {
                        _typeRepas = v.isEmpty ? null : v;
                        if (_typeRepas != 'Agape avec médaille') {
                          _medaille.clear();
                        }
                      }),
                      labelBuilder: (v) => v.isEmpty ? '-- Sélectionnez --' : v,
                    ),
                  ),
                ],
              ),
              if (_typeRepas == 'Agape avec médaille')
                _field(
                  _medaille,
                  'Montant de la médaille (€)',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
            ],

            const SizedBox(height: 12),
            const Divider(color: BrColors.gold),
            _field(
              _tronc,
              'Tronc de la Veuve (€)',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(_vmName, 'Vénérable Maître'),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BrColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isNew ? Icons.check_circle : Icons.save),
              label: Text(
                _saving
                    ? 'Traitement...'
                    : (isNew ? 'PLANIFIER' : 'ENREGISTRER'),
              ),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(icon, size: 18, color: BrColors.muted)
              : null,
        ),
      ),
    );
  }

  Widget _numberedField(String num, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$num.',
              style: const TextStyle(color: BrColors.gold, fontSize: 13),
            ),
          ),
          Expanded(
            child: TextField(
              controller: c,
              maxLines: null,
              style: const TextStyle(color: BrColors.text, fontSize: 13),
              decoration: InputDecoration(hintText: 'Travail $num'),
            ),
          ),
        ],
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
          if (picked != null) {
            setState(() {
              _date = picked;
              _regenerateTravaux();
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Date de reprise'),
          child: Text(
            _date == null
                ? 'Choisir'
                : DateFormat('d MMM y', 'fr_FR').format(_date!),
            style: TextStyle(
              color: _date == null ? BrColors.muted : BrColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onPick,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value ?? const TimeOfDay(hour: 20, minute: 0),
          );
          if (picked != null) onPick(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label),
          child: Text(
            value == null ? 'Choisir' : _fmtTime(value),
            style: TextStyle(
              color: value == null ? BrColors.muted : BrColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    String Function(String)? labelBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: BrColors.surface,
        isExpanded: true,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(labelBuilder != null ? labelBuilder(o) : o),
            ),
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
    child: Text(
      text,
      style: const TextStyle(
        color: BrColors.gold,
        fontSize: 12,
        letterSpacing: 1.5,
      ),
    ),
  );
}
