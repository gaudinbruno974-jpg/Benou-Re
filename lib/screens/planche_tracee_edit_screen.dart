// Éditeur de la planche tracée (équivalent de src/components/PlancheTraceeScreen.tsx).
//
// Le texte est pré-rempli avec le tracé généré automatiquement
// (`buildPlancheTraceeText`) puis librement modifiable ; il est enregistré dans
// `session.plancheDraftText` et repris tel quel par le PDF.
// L'édition est réservée au V∴M∴, au Secrétaire et aux administrateurs
// (`canEditSessions`) ; les autres rôles consultent l'écran en lecture seule.
//
// Sur une Tenue suspendue, le texte est figé : il s'affiche ligne par ligne et
// seul un commentaire peut être ajouté sous chacune (`plancheLineComments`) ;
// les notes de travaux, le tronc et le sac aux propositions restent éditables.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class PlancheTraceeEditScreen extends StatefulWidget {
  final String sessionId;
  const PlancheTraceeEditScreen({super.key, required this.sessionId});

  @override
  State<PlancheTraceeEditScreen> createState() =>
      _PlancheTraceeEditScreenState();
}

class _PlancheTraceeEditScreenState extends State<PlancheTraceeEditScreen> {
  final _text = TextEditingController();
  final _tronc = TextEditingController();
  final _sac = TextEditingController();
  final _notes = <TextEditingController>[];
  final _comments = <TextEditingController>[];
  List<String> _ordreDuJour = const [];
  List<String> _lines = const [];
  bool _initialized = false;
  bool _saving = false;

  void _initFrom(Session session, AppState state) {
    _ordreDuJour = plancheOrdreDuJour(session);
    final notes = session.plancheTravauxNotes;
    for (var i = 0; i < _ordreDuJour.length; i++) {
      _notes.add(TextEditingController(text: i < notes.length ? notes[i] : ''));
    }
    _tronc.text = session.troncAmount != 0 ? '${session.troncAmount}' : '';
    _sac.text = session.sacPropositions ?? '';
    final draft = (session.plancheDraftText ?? '').trim();
    _text.text = draft.isNotEmpty ? draft : _generatedText(session, state);
    _lines = plancheParagraphs(_text.text);
    final saved = session.plancheLineComments;
    for (var i = 0; i < _lines.length; i++) {
      _comments.add(TextEditingController(text: saved['$i'] ?? ''));
    }
    _initialized = true;
  }

  String _generatedText(Session session, AppState state) =>
      buildPlancheTraceeText(
        session,
        state.members,
        state.visitors,
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

  Future<void> _save(Session session) async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final map = Map<String, dynamic>.from(session.toMap());
    if (session.isSuspended) {
      final comments = <String, String>{};
      for (var i = 0; i < _comments.length; i++) {
        final v = _comments[i].text.trim();
        if (v.isNotEmpty) comments['$i'] = v;
      }
      map['plancheLineComments'] = comments;
      final body = (session.plancheDraftText ?? '').trim();
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
    try {
      await state.updateSession(Session.fromMap(session.id, map));
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
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => Session(id: widget.sessionId),
    );
    if (!_initialized) _initFrom(session, state);
    final canEdit = canEditSessions(state.currentUser);
    final isSuspended = session.isSuspended;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planche tracée'),
        actions: [
          if (canEdit)
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
              onPressed: _saving ? null : () => _save(session),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Lecture seule : seuls le Vénérable Maître, le Secrétaire et les administrateurs peuvent modifier la planche tracée.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: _Heading('TEXTE DE LA PLANCHE')),
              if (canEdit && !isSuspended)
                TextButton.icon(
                  onPressed: () => setState(
                    () => _text.text = _generatedText(session, state),
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
          if (isSuspended) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Tenue suspendue : le texte de la planche n\'est plus modifiable.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
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
                        enabled: canEdit,
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
              enabled: canEdit,
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
              enabled: canEdit,
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
              enabled: canEdit,
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
                  enabled: canEdit,
                  maxLines: null,
                  style: const TextStyle(color: BrColors.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: '${i + 1}. ${_ordreDuJour[i]}',
                    hintText: 'Note du Secrétaire…',
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          if (canEdit)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: BrColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Enregistrement…' : 'ENREGISTRER'),
              onPressed: _saving ? null : () => _save(session),
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
