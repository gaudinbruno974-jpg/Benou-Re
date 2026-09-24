// Création / modification d'une tenue pour un corps de Hauts Grades
// (IAH-MES) — même mécanique complète que session_edit_screen.dart (loges
// bleues), demande explicite de l'utilisateur : type de tenue, ordre du
// jour libre (travaux fixes + points complémentaires, dont des planches
// signées par un membre), agapes (avec médaille), chrono réservé,
// archivage Drive de la convocation. Adapté sur deux points seulement :
// le degré (4°-14°, Collège de Perfection, pas Apprenti/Compagnon/Maître)
// et le signataire (« Trois Fois Puissant Maître », champ libre — pas de
// V∴M∴ détecté automatiquement par office, cette notion n'existe pas ici).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agenda_item.dart';
import '../models/civilite.dart';
import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../services/drive_service.dart';
import '../services/hg_body_service.dart';
import '../services/hg_pdf_service.dart';
import '../theme.dart';
import '../utils/name_mask.dart';

const _sessionTypes = [
  'Ordinaire',
  'Extraordinaire',
  'Banquet',
  'Tenue blanche',
  'Tenue noire',
];
const _repasTypes = ['Agape avec médaille', 'Agape partage', 'Agape offerte'];

class _OrdreRow {
  final TextEditingController controller;
  String type;
  String authorId;
  String title;
  _OrdreRow({
    required this.controller,
    this.type = kAgendaItemSimple,
    this.authorId = '',
    this.title = '',
  });
}

/// Textes fixes générés par défaut (modifiables ensuite) — équivalent de
/// _travauxFixes/_ligneCloture (session_edit_screen.dart), avec la
/// terminologie du Collège de Perfection à la place de celle d'une loge
/// bleue (pas de « V∴M∴ », pas de « Degré symbolique du R∴A∴P∴M∴M∴ »).
/// « au 8e degré, au Grade de Maître Parfait » (IAH-MES) ou « au grade de
/// Maître » (MAA-Kherou, sans ladder ni numéro — confirmé par l'utilisateur).
String _degreePhraseForBody(HgBody body, int degree) {
  if (body.key == kMaaKherou.key) return 'au grade de Maître';
  final degreeName = kIahMesDegreeNames[degree] ?? '';
  return 'au $degree'
      'e degré, au Grade de $degreeName';
}

Map<String, String> _travauxFixes(
  HgBody body,
  int degree,
  TimeOfDay? heure,
  String signerName,
) {
  final h = heure != null
      ? '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}'
      : 'xxhxx';
  final signer = signerName.isEmpty ? 'Trois Fois Puissant Maître' : signerName;
  return {
    't1':
        '$h Ouverture des Travaux ${_degreePhraseForBody(body, degree)}, '
        'selon les usages et traditions de notre Ordre, par '
        'le Trois Fois Puissant Maître $signer.',
    't2': 'Lecture de l\'Ordre du Jour',
    't3': 'Appel des FF∴ et SS∴ du Collège',
  };
}

/// Point 4 « Travail collectif » — 3 blocs concaténés, demande explicite de
/// l'utilisateur : un titre fixe, le thème de la tenue (libre, propre à
/// chaque tenue, saisi dans un champ dédié), puis le rappel du protocole
/// (fixe, permanent, toujours identique).
String _travailCollectifText(String theme) {
  final t = theme.trim();
  return 'Travail collectif\n'
      '\n'
      '${t.isEmpty ? '' : '$t\n\n'}'
      'Rappel concernant le travail collectif\n'
      '\n'
      'La parole circule et chacun est invité à prendre part aux échanges :\n'
      '\n'
      'Quisque debet loqui\n'
      '« Que chacun puisse parler. »\n'
      '\n'
      '- Le temps de parole sera adapté au nombre de participants ;\n'
      '- Chaque S∴ ou F∴ pourra intervenir librement ;\n'
      '- Les interventions pourront être orales ou écrites ;\n'
      '- L\'écoute fraternelle et le respect de la parole de chacun seront '
      'privilégiés.';
}

String _ligneCloture(
  HgBody body,
  int degree,
  int ordresCount,
  String signerName,
) {
  final n = 4 + ordresCount + 1;
  final signer = signerName.isEmpty ? 'Trois Fois Puissant Maître' : signerName;
  final degreePhrase = body.key == kMaaKherou.key
      ? 'au grade de Maître'
      : 'au $degree'
            'e degré';
  return '$n. Fermeture des Travaux $degreePhrase par le Trois Fois '
      'Puissant Maître $signer.';
}

class GrandeLogeHgSessionEditScreen extends StatefulWidget {
  final HgBody body;
  final Session? session;

  /// Déverrouillage ponctuel (Sérénissime/titulaire) d'une tenue suspendue —
  /// même mécanique que SessionEditScreen.forceUnlock (loges bleues).
  final bool forceUnlock;

  const GrandeLogeHgSessionEditScreen({
    super.key,
    required this.body,
    this.session,
    this.forceUnlock = false,
  });

  @override
  State<GrandeLogeHgSessionEditScreen> createState() =>
      _GrandeLogeHgSessionEditScreenState();
}

class _GrandeLogeHgSessionEditScreenState
    extends State<GrandeLogeHgSessionEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _location;
  late final TextEditingController _chronoController;
  late final TextEditingController _signerCtrl;
  late final TextEditingController _t1;
  late final TextEditingController _t2;
  late final TextEditingController _t3;
  late final TextEditingController _t4;
  late final TextEditingController _theme;
  late final TextEditingController _cloture;
  late final TextEditingController _medaille;
  late final List<_OrdreRow> _ordres;

  late String _type;
  late int _degree;
  DateTime? _date;
  TimeOfDay? _heureReprise;
  TimeOfDay? _heureSuspension;
  TimeOfDay? _heureAgape;
  bool _hasAgape = false;
  String? _typeRepas;

  List<Member> _members = [];
  bool _saving = false;
  int? _autoChronoValue;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _location = TextEditingController(
      text: s?.location.isNotEmpty == true
          ? s!.location
          : 'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre',
    );
    _signerCtrl = TextEditingController(text: s?.vmName ?? 'Jean-Pierre T∴');
    if (s?.chrono != null) {
      _chronoController = TextEditingController(text: '${s!.chrono!.toInt()}');
      _autoChronoValue = s.chrono!.toInt();
    } else {
      _chronoController = TextEditingController(text: '');
      _autoChronoValue = null;
    }
    _t1 = TextEditingController(text: s?.travail1 ?? '');
    _t2 = TextEditingController(text: s?.travail2 ?? '');
    _t3 = TextEditingController(text: s?.travail3 ?? '');
    _theme = TextEditingController(
      text: (s?.extra['travail4Theme'] as String?) ?? '',
    );
    _t4 = TextEditingController(
      text: s?.travail4 ?? _travailCollectifText(_theme.text),
    );
    _cloture = TextEditingController(text: s?.ligneCloture ?? '');
    _medaille = TextEditingController(
      text: (s?.montantMedaille ?? 0) > 0 ? '${s!.montantMedaille}' : '',
    );

    final items = (s?.agendaItems ?? const <AgendaItem>[])
        .where((i) => i.text.trim().isNotEmpty)
        .toList();
    _ordres = [
      for (final i in items)
        _OrdreRow(
          controller: TextEditingController(text: i.text),
          type: i.type,
          authorId: i.authorId,
          title: i.title,
        ),
      // Nouvelle tenue (aucun ordre du jour enregistré) : « Questions
      // diverses » pré-rempli par défaut, toujours présent — demande
      // explicite de l'utilisateur. Reste modifiable/supprimable comme
      // n'importe quelle autre ligne.
      if (items.isEmpty)
        _OrdreRow(
          controller: TextEditingController(text: 'Questions diverses'),
        ),
    ];

    _type = _ensure(s?.typeTenue ?? s?.type, 'Ordinaire');
    // MAA-Kherou travaille uniquement au grade de Maître (3, convention des
    // loges bleues) — pas de ladder 4°-14°, pas de sélecteur de degré (voir
    // build() ci-dessous), confirmé par l'utilisateur.
    _degree = widget.body.key == kMaaKherou.key
        ? 3
        : (int.tryParse(s?.degreTravail ?? s?.degree ?? '') ?? 4);
    _date = s?.dateTime;
    _heureReprise = _date != null && (_date!.hour != 0 || _date!.minute != 0)
        ? TimeOfDay(hour: _date!.hour, minute: _date!.minute)
        : null;
    _heureSuspension = _parseTime(s?.heureSuspension ?? s?.closingTime);
    _heureAgape = _parseTime(s?.heureAgape);
    _hasAgape = s?.suitAgapes ?? false;
    _typeRepas = _repasTypes.contains(s?.typeRepas) ? s!.typeRepas : null;

    HgBodyService.instance.membersOnce(widget.body).then((members) {
      if (mounted) setState(() => _members = members);
    });

    // Nouvelle tenue : pré-remplit les travaux fixes (1-4) et la ligne de
    // clôture dès l'ouverture, plutôt que d'attendre que l'utilisateur
    // touche au degré/à l'heure — jusqu'ici ils restaient vides tant que
    // rien ne déclenchait _regenerateTravaux().
    if (widget.session == null) {
      _regenerateTravaux();
    }
  }

  String _ensure(String? value, String fallback) {
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

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
      _chronoController,
      _signerCtrl,
      _t1,
      _t2,
      _t3,
      _t4,
      _theme,
      _cloture,
      _medaille,
    ]) {
      c.dispose();
    }
    for (final r in _ordres) {
      r.controller.dispose();
    }
    super.dispose();
  }

  bool get _dateLocked => widget.session != null;

  int get _ordresCount =>
      _ordres.where((r) => r.controller.text.trim().isNotEmpty).length;

  void _regenerateTravaux() {
    final fixes = _travauxFixes(
      widget.body,
      _degree,
      _heureReprise,
      _signerCtrl.text.trim(),
    );
    _t1.text = fixes['t1']!;
    _t2.text = fixes['t2']!;
    _t3.text = fixes['t3']!;
    _t4.text = _travailCollectifText(_theme.text);
    _regenerateCloture();
  }

  void _regenerateCloture() {
    _cloture.text = _ligneCloture(
      widget.body,
      _degree,
      _ordresCount,
      _signerCtrl.text.trim(),
    );
  }

  Future<void> _configureRow(int index) async {
    final row = _ordres[index];
    final members = List<Member>.from(_members)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    String type = row.type;
    String authorId = row.authorId;
    final titleController = TextEditingController(text: row.title);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: BrColors.surface,
              title: const Text('Configurer ce point'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: kAgendaItemSimple,
                          label: Text('Point simple'),
                          icon: Icon(Icons.short_text, size: 16),
                        ),
                        ButtonSegment(
                          value: kAgendaItemPlanche,
                          label: Text('Planche'),
                          icon: Icon(Icons.menu_book_outlined, size: 16),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) =>
                          setDialogState(() => type = s.first),
                    ),
                    if (type == kAgendaItemPlanche) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: authorId.isEmpty ? null : authorId,
                        dropdownColor: BrColors.surface,
                        decoration: const InputDecoration(labelText: 'Auteur'),
                        items: [
                          for (final m in members)
                            DropdownMenuItem(
                              value: m.id,
                              child: Text(m.fullName),
                            ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => authorId = v ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(color: BrColors.text),
                        decoration: const InputDecoration(
                          labelText: 'Titre (facultatif)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: (type == kAgendaItemPlanche && authorId.isEmpty)
                      ? null
                      : () => Navigator.pop(dialogContext, true),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        row.type = type;
        if (type == kAgendaItemPlanche) {
          row.authorId = authorId;
          row.title = titleController.text.trim();
          final author = members.firstWhere((m) => m.id == authorId);
          row.controller.text = agendaPlancheLine(
            authorDisplayName:
                '${civiliteAbbrev(author.civilite)} ${maskPersonName(author.fullName)}',
            title: row.title,
          );
        } else {
          row.authorId = '';
          row.title = '';
        }
        _regenerateCloture();
      });
    }
    titleController.dispose();
  }

  Future<void> _archiveConvocation(Session session, int chrono) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = Uint8List.fromList(
      await buildIahMesConvocationPdf(widget.body, session),
    );
    final dateStr = DateFormat('dd MM yy').format(DateTime.now());
    try {
      await DriveService.instance.archiveGenericDocument(
        folderName: 'Tenues ${widget.body.label}',
        fileName: 'Convocation $chrono ${widget.body.label} $dateStr.pdf',
        bytes: bytes,
      );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Convocation archivée sur Drive.'),
            backgroundColor: BrColors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Archivage Drive : $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final existing = widget.session;
    final id = existing?.id ?? 's_${DateTime.now().millisecondsSinceEpoch}';
    final dateOnly = _dateLocked && (existing?.date.isNotEmpty ?? false)
        ? existing!.date
        : DateFormat('yyyy-MM-dd').format(_date!);
    final dateReprise = _heureReprise != null
        ? '${dateOnly}T${_heureReprise!.hour.toString().padLeft(2, '0')}:${_heureReprise!.minute.toString().padLeft(2, '0')}'
        : dateOnly;
    final closing = _heureSuspension != null ? _fmtTime(_heureSuspension!) : '';
    final validRows = _ordres.where((r) => r.controller.text.trim().isNotEmpty);
    final ordres = [for (final r in validRows) r.controller.text.trim()];
    final agendaItems = [
      for (final r in validRows)
        AgendaItem(
          text: r.controller.text.trim(),
          type: r.type,
          authorId: r.authorId,
          title: r.title,
        ).toMap(),
    ];

    final map = <String, dynamic>{
      if (existing != null) ...existing.toMap(),
      'id': id,
      'title': '',
      'date': dateOnly,
      'dateReprise': dateReprise,
      'type': _type,
      'typeTenue': _type,
      'degree': '$_degree',
      'degreTravail': '$_degree',
      'vmName': _signerCtrl.text.trim(),
      'location': _location.text.trim(),
      'lieuReunion': _location.text.trim(),
      'closingTime': closing,
      'heureSuspension': closing,
      'travail1': _t1.text.trim(),
      'travail2': _t2.text.trim(),
      'travail3': _t3.text.trim(),
      'travail4': _t4.text.trim(),
      'travail4Theme': _theme.text.trim(),
      'ordresJour': ordres,
      'agendaItems': agendaItems,
      'ligneCloture': _cloture.text.trim(),
      'hasAgape': _hasAgape,
      'suitAgapes': _hasAgape,
      'status': existing?.statut == 'Annulée'
          ? 'Planifiée'
          : (existing?.statut ?? 'Planifiée'),
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
      int? chrono = existing?.chrono?.toInt() ?? _autoChronoValue;
      if (existing == null && chrono == null) {
        chrono = await HgBodyService.instance.allocateSessionChrono(
          widget.body,
        );
      }
      if (chrono != null) {
        map['chrono'] = chrono;
        map['sessionNumber'] = '$chrono';
      }
      final session = Session.fromMap(id, map);
      if (existing == null) {
        await HgBodyService.instance.addSession(widget.body, session);
        if (chrono != null) {
          await _archiveConvocation(session, chrono);
        }
      } else {
        await HgBodyService.instance.updateSession(widget.body, session);
      }
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur enregistrement : $e')),
        );
      }
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isNew = widget.session == null;
    final readOnly = widget.session?.isSuspended == true && !widget.forceUnlock;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nouvelle tenue' : 'Modifier la tenue'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            _dropdownStr(
              'Type de Tenue',
              _type,
              _itemsWith(_sessionTypes, _type),
              (v) => setState(() => _type = v),
              enabled: !readOnly,
            ),
            // MAA-Kherou : pas de sélecteur, la tenue se tient toujours au
            // grade de Maître (_degree fixé à 3 dans initState).
            if (widget.body.key != kMaaKherou.key)
              _dropdownInt(
                'Degré',
                _degree,
                (v) => setState(() {
                  _degree = v;
                  _regenerateTravaux();
                }),
                enabled: !readOnly,
              ),
            _field(
              _signerCtrl,
              'Trois Fois Puissant Maître',
              enabled: !readOnly,
            ),
            _field(
              _chronoController,
              _autoChronoValue != null
                  ? 'Chrono réservé'
                  : 'Chrono (attribué à l\'enregistrement)',
              enabled: false,
              keyboard: TextInputType.number,
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
                    enabled: !readOnly,
                  ),
                ),
              ],
            ),
            _timeField(
              'Heure de suspension (clôture)',
              _heureSuspension,
              (t) => setState(() => _heureSuspension = t),
              enabled: !readOnly,
            ),
            _field(
              _location,
              'Lieu de Réunion',
              icon: Icons.place_outlined,
              enabled: !readOnly,
            ),
            const SizedBox(height: 8),
            _Heading('ORDRE DU JOUR — TRAVAUX FIXES'),
            _numberedField('1', _t1, enabled: !readOnly),
            _numberedField('2', _t2, enabled: !readOnly),
            _numberedField('3', _t3, enabled: !readOnly),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: TextField(
                controller: _theme,
                enabled: !readOnly,
                maxLines: null,
                minLines: 3,
                style: const TextStyle(color: BrColors.text),
                decoration: const InputDecoration(
                  labelText: 'Thème du travail collectif (point 4)',
                  hintText:
                      '« Titre du thème »\n\nQuestion ou texte introductif…',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) =>
                    setState(() => _t4.text = _travailCollectifText(v)),
              ),
            ),
            _numberedField('4', _t4, enabled: !readOnly),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: _Heading('ORDRES DU JOUR COMPLÉMENTAIRES'),
                ),
                TextButton.icon(
                  onPressed: readOnly
                      ? null
                      : () => setState(
                          () => _ordres.add(
                            _OrdreRow(controller: TextEditingController()),
                          ),
                        ),
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
                    IconButton(
                      tooltip: _ordres[i].type == kAgendaItemPlanche
                          ? 'Planche — modifier'
                          : 'Point simple — passer en Planche',
                      icon: Icon(
                        _ordres[i].type == kAgendaItemPlanche
                            ? Icons.menu_book_outlined
                            : Icons.short_text,
                        size: 18,
                        color: _ordres[i].type == kAgendaItemPlanche
                            ? BrColors.gold
                            : BrColors.muted,
                      ),
                      onPressed: readOnly ? null : () => _configureRow(i),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _ordres[i].controller,
                        readOnly: _ordres[i].type == kAgendaItemPlanche,
                        style: const TextStyle(color: BrColors.text),
                        decoration: InputDecoration(
                          hintText: 'ex : Thème de la tenue...',
                          suffixIcon: _ordres[i].type == kAgendaItemPlanche
                              ? const Icon(Icons.lock_outline, size: 16)
                              : null,
                        ),
                        onTap:
                            (readOnly || _ordres[i].type != kAgendaItemPlanche)
                            ? null
                            : () => _configureRow(i),
                        onChanged: readOnly
                            ? null
                            : (_) => setState(_regenerateCloture),
                        enabled: !readOnly,
                      ),
                    ),
                    if (_ordres.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: BrColors.muted,
                        ),
                        onPressed: readOnly
                            ? null
                            : () => setState(() {
                                _ordres.removeAt(i).controller.dispose();
                                _regenerateCloture();
                              }),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _field(_cloture, 'Ligne de clôture', enabled: !readOnly),
            const SizedBox(height: 16),
            Divider(color: BrColors.gold.withValues(alpha: 0.35), height: 28),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Suit-elle d'Agapes fraternelles ?",
                style: TextStyle(color: BrColors.gold, letterSpacing: 1),
              ),
              activeThumbColor: BrColors.teal,
              value: _hasAgape,
              onChanged: readOnly
                  ? null
                  : (v) => setState(() {
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
                      enabled: !readOnly,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdownStr(
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
                      enabled: !readOnly,
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
                  enabled: !readOnly,
                ),
            ],
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BrColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
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

  List<String> _itemsWith(List<String> base, String value) =>
      base.contains(value) ? base : [...base, value];

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    IconData? icon,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
        enabled: enabled,
      ),
    );
  }

  Widget _numberedField(
    String num,
    TextEditingController c, {
    bool enabled = true,
  }) {
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
              enabled: enabled,
              style: const TextStyle(color: BrColors.text, fontSize: 13),
              decoration: InputDecoration(hintText: 'Travail $num'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField() {
    final locked = _dateLocked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: locked
            ? null
            : () async {
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
          decoration: InputDecoration(
            labelText: 'Date de reprise',
            enabled: !locked,
            suffixIcon: locked
                ? const Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: BrColors.muted,
                  )
                : null,
          ),
          child: Text(
            _date == null
                ? 'Choisir'
                : DateFormat('d MMM y', 'fr_FR').format(_date!),
            style: TextStyle(
              color: (_date == null || locked) ? BrColors.muted : BrColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeField(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay> onPick, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: !enabled
            ? null
            : () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: value ?? const TimeOfDay(hour: 20, minute: 0),
                );
                if (picked != null) onPick(picked);
              },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, enabled: enabled),
          child: Text(
            value == null ? 'Choisir' : _fmtTime(value),
            style: TextStyle(
              color: value == null || !enabled ? BrColors.muted : BrColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownStr(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    String Function(String)? labelBuilder,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: BrColors.surface,
        isExpanded: true,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label, enabled: enabled),
        items: [
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(labelBuilder != null ? labelBuilder(o) : o),
            ),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
      ),
    );
  }

  Widget _dropdownInt(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        dropdownColor: BrColors.surface,
        isExpanded: true,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label, enabled: enabled),
        items: [
          for (final entry in kIahMesDegreeNames.entries)
            DropdownMenuItem(
              value: entry.key,
              child: Text('${entry.key}e degré — ${entry.value}'),
            ),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 10),
    child: Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: BrColors.gold,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: BrColors.gold.withValues(alpha: 0.2),
          ),
        ),
      ],
    ),
  );
}
