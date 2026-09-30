// Planche tracée (compte-rendu du travail collectif) d'une tenue d'un
// corps de Hauts Grades — même principe que planche_tracee_edit_screen.dart
// (loges bleues) : texte rituel généré automatiquement
// (buildIahMesPlancheTraceeText, hg_pdf_service.dart) à partir des données
// réelles de la tenue, librement modifiable ensuite, avec Tronc de la
// Veuve, Sac aux propositions et notes de travaux par point d'ordre du
// jour. Sur une tenue suspendue, le texte est figé (affiché ligne par
// ligne, commentaire possible sous chacune) — le Trois Fois Puissant
// Maître peut lever ce verrou ponctuellement (forceUnlock, même mécanique
// que SessionEditScreen/GrandeLogeHgSessionEditScreen).
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../services/hg_pdf_service.dart' show buildIahMesPlancheTraceeText;
import '../services/pdf_service.dart'
    show plancheOrdreDuJour, plancheParagraphs, plancheTextWithTronc;
import '../theme.dart';

class GrandeLogeHgPlancheScreen extends StatefulWidget {
  final HgBody body;
  final Session session;

  /// Déverrouillage ponctuel d'une tenue suspendue — même mécanique que
  /// PlancheTraceeEditScreen.forceUnlock (loges bleues).
  final bool forceUnlock;

  const GrandeLogeHgPlancheScreen({
    super.key,
    required this.body,
    required this.session,
    this.forceUnlock = false,
  });

  @override
  State<GrandeLogeHgPlancheScreen> createState() =>
      _GrandeLogeHgPlancheScreenState();
}

class _GrandeLogeHgPlancheScreenState extends State<GrandeLogeHgPlancheScreen> {
  final _text = TextEditingController();
  final _tronc = TextEditingController();
  final _sac = TextEditingController();
  final _notes = <TextEditingController>[];
  final _comments = <TextEditingController>[];
  List<String> _ordreDuJour = const [];
  List<String> _lines = const [];
  late bool _validated;
  bool _initialized = false;
  bool _saving = false;

  List<Member> _members = [];
  List<Visitor> _visitors = [];
  List<Dignitary> _dignitaries = [];

  @override
  void initState() {
    super.initState();
    _validated = widget.session.plancheValidated;
    // Membres/Visiteurs/Dignitaires nécessaires à la génération du texte
    // (excusés, placement à l'Orient...) : chargés une fois avant de
    // pré-remplir, pas de génération à partir de listes encore vides —
    // contrairement aux loges bleues où AppState est déjà chaud à
    // l'ouverture de cet écran.
    Future.wait([
      HgBodyService.instance.membersOnce(widget.body),
      HgBodyService.instance.visitorsStream(widget.body).first,
      HgBodyService.instance.dignitariesStream(widget.body).first,
    ]).then((results) {
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<Member>;
        _visitors = results[1] as List<Visitor>;
        _dignitaries = results[2] as List<Dignitary>;
        _initFrom(widget.session);
      });
    });
  }

  void _initFrom(Session session) {
    _ordreDuJour = plancheOrdreDuJour(session);
    final notes = session.plancheTravauxNotes;
    for (var i = 0; i < _ordreDuJour.length; i++) {
      _notes.add(TextEditingController(text: i < notes.length ? notes[i] : ''));
    }
    _tronc.text = session.troncAmount != 0 ? '${session.troncAmount}' : '';
    _sac.text = session.sacPropositions ?? '';
    final draft = (session.plancheDraftText ?? '').trim();
    _text.text = draft.isNotEmpty ? draft : _generatedText(session);
    _lines = plancheParagraphs(_text.text);
    final saved = session.plancheLineComments;
    for (var i = 0; i < _lines.length; i++) {
      _comments.add(TextEditingController(text: saved['$i'] ?? ''));
    }
    _initialized = true;
  }

  String _generatedText(Session session) => buildIahMesPlancheTraceeText(
    widget.body,
    session,
    _members,
    _visitors,
    _dignitaries,
    _chrono(session),
    troncAmount: _troncValue(),
    sacPropositions: _sac.text.trim(),
    travauxNotes: _notes.map((c) => c.text.trim()).toList(),
  );

  num _troncValue() =>
      num.tryParse(_tronc.text.trim().replaceAll(',', '.')) ?? 0;

  int _chrono(Session s) {
    if (s.chrono != null) return s.chrono!.toInt();
    return int.tryParse(
          (s.sessionNumber ?? '').replaceAll(RegExp(r'[^\d]'), ''),
        ) ??
        0;
  }

  @override
  void dispose() {
    _text.dispose();
    _tronc.dispose();
    _sac.dispose();
    for (final c in _notes) {
      c.dispose();
    }
    for (final c in _comments) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final map = Map<String, dynamic>.from(widget.session.toMap());
    final locked = widget.session.isSuspended && !widget.forceUnlock;
    if (locked) {
      final comments = <String, String>{};
      for (var i = 0; i < _comments.length; i++) {
        final v = _comments[i].text.trim();
        if (v.isNotEmpty) comments['$i'] = v;
      }
      map['plancheLineComments'] = comments;
      final body = (widget.session.plancheDraftText ?? '').trim();
      if (body.isNotEmpty) {
        map['plancheDraftText'] = plancheTextWithTronc(
          body,
          _troncValue(),
          _sac.text.trim(),
        );
      }
    } else {
      map['plancheDraftText'] = _text.text.trim();
    }
    map['troncAmount'] = _troncValue();
    map['sacPropositions'] = _sac.text.trim();
    map['plancheTravauxNotes'] = _notes.map((c) => c.text.trim()).toList();
    map['plancheValidated'] = _validated;
    try {
      final updated = Session.fromMap(widget.session.id, map);
      await HgBodyService.instance.updateSession(widget.body, updated);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Planche tracée enregistrée.'),
          backgroundColor: BrColors.teal,
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur enregistrement : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: BrColors.gold)),
      );
    }
    final locked = widget.session.isSuspended && !widget.forceUnlock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planche tracée'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrColors.gold,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (locked)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Tenue suspendue : le texte de la planche n\'est plus '
                'modifiable.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: _Heading('TEXTE DE LA PLANCHE')),
              if (!locked)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _text.text = _generatedText(widget.session),
                  ),
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: BrColors.teal,
                  ),
                  label: const Text(
                    'Régénérer',
                    style: TextStyle(color: BrColors.teal, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (locked) ...[
            for (var i = 0; i < _lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lines[i],
                      style: const TextStyle(
                        color: BrColors.text,
                        fontSize: 13,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 2),
                      child: TextField(
                        controller: _comments[i],
                        maxLines: null,
                        style: const TextStyle(
                          color: BrColors.teal,
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Ajouter un commentaire…',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else
            TextField(
              controller: _text,
              maxLines: null,
              minLines: 18,
              style: const TextStyle(color: BrColors.text, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Texte de la planche tracée…',
                alignLabelWithHint: true,
              ),
            ),
          const SizedBox(height: 20),
          const _Heading('TRONC & SAC AUX PROPOSITIONS'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _tronc,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                labelText: 'Tronc de la Veuve (€)',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _sac,
              maxLines: null,
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                labelText: 'Sac aux propositions',
              ),
            ),
          ),
          if (_ordreDuJour.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _Heading('NOTES DE TRAVAUX'),
            for (var i = 0; i < _ordreDuJour.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: _notes[i],
                  maxLines: null,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: '${i + 1}. ${_ordreDuJour[i]}',
                    hintText: 'Note…',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: BrColors.teal,
            title: const Text(
              'Planche validée',
              style: TextStyle(color: BrColors.text),
            ),
            value: _validated,
            onChanged: (v) => setState(() => _validated = v),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: BrColors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Enregistrement…' : 'ENREGISTRER'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: BrColors.gold,
          fontSize: 12,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
