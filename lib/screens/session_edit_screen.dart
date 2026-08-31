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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/agenda_item.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../utils/name_mask.dart';

const _sessionTypes = [
  'Ordinaire',
  'Extraordinaire',
  'Banquet',
  'Tenue blanche',
  'Tenue noire',
];
const _degrees = kGrades;
const _repasTypes = ['Agape avec médaille', 'Agape partage', 'Agape offerte'];

/// Un point d'ordre du jour complémentaire en cours d'édition : le
/// contrôleur porte la ligne affichée/imprimée (déjà composée et tronquée
/// pour une planche, voir agendaPlancheLine), type/authorId/title ne
/// servent qu'à ré-ouvrir la boîte de configuration et à retrouver l'auteur
/// réel côté Statistiques/Rapport (agendaItems, voir session.dart).
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

// ─── Générateurs de textes (portés de SessionsList.tsx) ──────────────────
// Le V∴M∴ mentionné est celui qui préside réellement les travaux : résolu
// depuis config/settings ou la fiche membre portant l'office (même repli que
// plancheVmName), jamais un nom figé — sans quoi le texte généré par défaut
// resterait celui du flavor d'origine (benoure) quelle que soit la loge.
Map<String, String> _travauxFixes(String degre, TimeOfDay? heure, String vmName) {
  final ord = Session.degreeOrdinal(degre);
  final h = heure != null
      ? '${heure.hour.toString().padLeft(2, '0')}h${heure.minute.toString().padLeft(2, '0')}'
      : 'xxhxx';
  return {
    't1':
        '$h Ouverture des Travaux au $ord Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ $vmName.',
    't2': 'Appel des FF∴ et SS∴ de la loge',
    't3':
        'Lecture de la planche tracée de nos derniers travaux au $ord Degré symbolique.',
    't4': 'Lecture de la correspondance et des affaires diverses.',
  };
}

String _ligneCloture(String degre, int ordresCount, String vmName) {
  final ord = Session.degreeOrdinal(degre);
  final n = 4 + ordresCount + 1;
  return '$n. Clôture des Travaux au $ord Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ $vmName.';
}

class SessionEditScreen extends StatefulWidget {
  final Session? session;

  /// Déverrouillage ponctuel (V∴M∴) d'une tenue suspendue — voir
  /// SessionDetailScreen. N'est jamais persisté : si on rouvre cette même
  /// tenue plus tard sans repasser par le bouton de déverrouillage, elle
  /// redevient strictement en lecture seule.
  final bool forceUnlock;

  const SessionEditScreen({
    super.key,
    this.session,
    this.forceUnlock = false,
  });

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _location;
  late final TextEditingController _chronoController;
  late final TextEditingController _t1;
  late final TextEditingController _t2;
  late final TextEditingController _t3;
  late final TextEditingController _t4;
  late final TextEditingController _cloture;
  late final TextEditingController _medaille;
  late final List<_OrdreRow> _ordres;

  late String _type;
  late String _degree;
  DateTime? _date;
  TimeOfDay? _heureReprise;
  TimeOfDay? _heureSuspension;
  TimeOfDay? _heureAgape;
  bool _hasAgape = false;
  String? _typeRepas;

  bool _saving = false;
  bool _driveAuthInProgress = false;
  int? _autoChronoValue;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _location = TextEditingController(
      text: s?.location.isNotEmpty == true
          ? s!.location
          : (s?.lieuReunion ?? LodgeConfig.current.defaultMeetingPlace),
    );
    if (s?.chrono != null) {
      _chronoController = TextEditingController(text: '${s!.chrono!.toInt()}');
      _autoChronoValue = s.chrono!.toInt();
    } else {
      _chronoController = TextEditingController(text: '');
      _autoChronoValue = null;
      if (widget.session == null) {
        _loadAutoChrono();
      }
    }
    _t1 = TextEditingController(text: s?.travail1 ?? '');
    _t2 = TextEditingController(text: s?.travail2 ?? '');
    _t3 = TextEditingController(text: s?.travail3 ?? '');
    _t4 = TextEditingController(text: s?.travail4 ?? '');
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
      if (items.isEmpty) _OrdreRow(controller: TextEditingController()),
    ];

    _type = _ensure(s?.typeTenue ?? s?.type, 'Ordinaire');
    _degree = _ensure(normalizeGrade(s?.degreTravail ?? s?.degree), 'Apprenti');
    _date = s?.dateTime;
    _heureReprise = _date != null && (_date!.hour != 0 || _date!.minute != 0)
        ? TimeOfDay(hour: _date!.hour, minute: _date!.minute)
        : null;
    _heureSuspension = _parseTime(s?.heureSuspension ?? s?.closingTime);
    _heureAgape = _parseTime(s?.heureAgape);
    _hasAgape = s?.suitAgapes ?? false;
    _typeRepas = _repasTypes.contains(s?.typeRepas) ? s!.typeRepas : null;
  }

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

  Future<void> _loadAutoChrono() async {
    try {
      final state = context.read<AppState>();
      final chrono = await state.allocateSessionChrono();
      if (!mounted) return;
      if (_chronoController.text.isEmpty) {
        setState(() {
          _chronoController.text = '$chrono';
          _autoChronoValue = chrono;
        });
      }
    } catch (_) {
      // Ignore: le numéro sera généré à l'enregistrement si nécessaire.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _location,
      _chronoController,
      _t1,
      _t2,
      _t3,
      _t4,
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

  /// Une Tenue existante garde sa date : le dossier Drive porte cette date.
  bool get _dateLocked => widget.session != null;

  int get _ordresCount =>
      _ordres.where((r) => r.controller.text.trim().isNotEmpty).length;

  /// Nom du V∴M∴ actuellement en charge, résolu comme pour la planche
  /// tracée (config/settings, sinon la fiche membre portant l'office), et
  /// masqué à la manière maçonnique : ce nom alimente le texte généré par
  /// défaut de la convocation (un document), jamais un affichage interne.
  String get _currentVmName {
    final state = context.read<AppState>();
    return maskPersonName(
      plancheVmName(
        const Session(id: ''),
        state.members,
        lodgeVmName: state.lodgeVmName,
      ),
    );
  }

  void _regenerateTravaux() {
    final fixes = _travauxFixes(_degree, _heureReprise, _currentVmName);
    _t1.text = fixes['t1']!;
    _t2.text = fixes['t2']!;
    _t3.text = fixes['t3']!;
    _t4.text = fixes['t4']!;
    _regenerateCloture();
  }

  void _regenerateCloture() {
    _cloture.text = _ligneCloture(_degree, _ordresCount, _currentVmName);
  }

  /// Boîte de configuration d'un point d'ordre du jour complémentaire :
  /// bascule Point simple / Planche, et pour une planche, choix de l'auteur
  /// (un membre de la Loge, jamais un Visiteur ni un Dignitaire) et titre
  /// facultatif. La ligne affichée est recomposée à l'enregistrement — la
  /// saisie libre n'est proposée que pour un point simple.
  Future<void> _configureRow(int index) async {
    final row = _ordres[index];
    final members = List<Member>.from(context.read<AppState>().members)
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
                            DropdownMenuItem(value: m.id, child: Text(m.fullName)),
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
            authorDisplayName: maskPersonName(author.fullName),
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

  // ─── ARCHIVAGE DRIVE À LA CRÉATION (best effort) ──────────────────
  Future<Session> _createDriveFolder(Session session, int chrono) async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    final pdf = Uint8List.fromList(
      await buildConvocationPdf(
        session,
        chrono,
        state.members,
        lodgeVmName: state.lodgeVmName,
      ),
    );
    final res = await DriveService.instance.ensureFolderAndUpload(session, {
      'Convocation ${LodgeConfig.current.name} Tenue $chrono'
          '${session.driveFileDateGradeSuffix}.pdf': pdf,
    });
    final map = session.toMap();
    map['driveFolderId'] = res.folderId;
    map['driveFolderUrl'] = res.folderUrl;
    final result = Session.fromMap(session.id, map);
    if (!mounted) return result;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Dossier Drive créé par ${res.email}'),
        backgroundColor: BrColors.teal,
      ),
    );
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une date.')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final state = context.read<AppState>();
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
      'degree': _degree,
      'degreTravail': _degree,
      'location': _location.text.trim(),
      'lieuReunion': _location.text.trim(),
      'closingTime': closing,
      'heureSuspension': closing,
      'travail1': _t1.text.trim(),
      'travail2': _t2.text.trim(),
      'travail3': _t3.text.trim(),
      'travail4': _t4.text.trim(),
      'ordresJour': ordres,
      'agendaItems': agendaItems,
      'ligneCloture': _cloture.text.trim(),
      'hasAgape': _hasAgape,
      'suitAgapes': _hasAgape,
      // Modifier une tenue Annulée équivaut à la reprogrammer : elle
      // redevient active plutôt que de rester affichée comme annulée.
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
      int? chrono = widget.forceUnlock
          ? (int.tryParse(_chronoController.text.trim()) ??
                existing?.chrono?.toInt())
          : (existing?.chrono?.toInt() ?? _autoChronoValue);
      if (existing == null && chrono == null) {
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
            await DriveService.instance.ensureDriveAuthorization();
            await state.updateSession(
              await _createDriveFolder(session, chrono),
            );
          } catch (e) {
            if (mounted) {
              final message = e.toString();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Dossier Drive non créé : $message\n'
                    '${kIsWeb ? 'Vous êtes sur le Web : vérifiez la configuration OAuth Google Drive et les permissions de l\'application.' : ''}',
                  ),
                  backgroundColor: BrColors.error,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          }
        }
      } else {
        await state.updateSession(session);
      }

      if (mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final messenger = ScaffoldMessenger.of(context);
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
    final ord = Session.degreeOrdinal(_degree);
    final canEdit = canEditSessions(context.watch<AppState>().currentUser);

    if (!canEdit) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tenue')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Seuls le V∴M∴, le Secrétaire et les administrateurs peuvent créer ou modifier une tenue.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrColors.muted),
            ),
          ),
        ),
      );
    }

    // Tenue suspendue (classée dans l'onglet « Travaux Suspendus ») :
    // les travaux ne sont plus modifiables — sauf déverrouillage ponctuel
    // par le V∴M∴ (forceUnlock, voir SessionDetailScreen).
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
            _dropdown(
              'Type de Tenue',
              _type,
              _itemsWith(_sessionTypes, _type),
              (v) => setState(() => _type = v),
              enabled: !readOnly,
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
              enabled: !readOnly,
            ),
            _field(
              _chronoController,
              widget.forceUnlock ? 'Chrono (déverrouillé)' : 'Chrono réservé',
              enabled: widget.forceUnlock,
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
            _Heading('ORDRE DU JOUR — TRAVAUX FIXES ($ord Degré)'),
            _numberedField('1', _t1, enabled: !readOnly),
            _numberedField('2', _t2, enabled: !readOnly),
            _numberedField('3', _t3, enabled: !readOnly),
            _numberedField('4', _t4, enabled: !readOnly),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                readOnly
                    ? 'Les travaux ne sont plus modifiables (Tenue suspendue).'
                    : 'Tous les travaux peuvent être modifiés.',
                style: const TextStyle(color: BrColors.muted, fontSize: 11),
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
                          hintText: 'ex : Lecture de la correspondance...',
                          suffixIcon: _ordres[i].type == kAgendaItemPlanche
                              ? const Icon(Icons.lock_outline, size: 16)
                              : null,
                        ),
                        onTap: (readOnly || _ordres[i].type != kAgendaItemPlanche)
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
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Numéro auto-généré : ${4 + _ordresCount + 1}° (texte modifiable).',
                style: const TextStyle(color: BrColors.muted, fontSize: 11),
              ),
            ),

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
            if (kIsWeb && !readOnly) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _driveAuthInProgress
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: const Text('CONNECTER DRIVE'),
                onPressed: _driveAuthInProgress
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _driveAuthInProgress = true);
                        try {
                          await DriveService.instance
                              .ensureDriveAuthorization();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Accès Google Drive accordé. Vous pouvez maintenant planifier la tenue.',
                              ),
                              backgroundColor: BrColors.teal,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Connexion Drive impossible : $e'),
                              backgroundColor: BrColors.error,
                              duration: const Duration(seconds: 6),
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _driveAuthInProgress = false;
                            });
                          }
                        }
                      },
              ),
              const SizedBox(height: 12),
            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
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
                  color: (_date == null || locked)
                      ? BrColors.muted
                      : BrColors.text,
                ),
              ),
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'La date ne peut plus être modifiée après validation (le dossier Drive porte cette date).',
                style: TextStyle(color: BrColors.muted, fontSize: 11),
              ),
            ),
        ],
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

  Widget _dropdown(
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
