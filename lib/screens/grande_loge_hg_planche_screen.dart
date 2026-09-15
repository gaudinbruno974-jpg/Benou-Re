// Planche tracée (compte-rendu du travail collectif) d'une tenue d'un
// corps de Hauts Grades — équivalent simplifié de
// planche_tracee_edit_screen.dart (loges bleues) : un seul texte, pas de
// distinction planche/ordres du jour complémentaires, la signature se fait
// depuis l'écran Émargement.
import 'package:flutter/material.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgPlancheScreen extends StatefulWidget {
  final HgBody body;
  final HgSession session;
  const GrandeLogeHgPlancheScreen({
    super.key,
    required this.body,
    required this.session,
  });

  @override
  State<GrandeLogeHgPlancheScreen> createState() =>
      _GrandeLogeHgPlancheScreenState();
}

class _GrandeLogeHgPlancheScreenState extends State<GrandeLogeHgPlancheScreen> {
  late final TextEditingController _textCtrl;
  late bool _validated;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.session.plancheText);
    _validated = widget.session.plancheValidated;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = widget.session.copyWith(
        plancheText: _textCtrl.text.trim(),
        plancheValidated: _validated,
      );
      await HgBodyService.instance.saveSession(widget.body, updated);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planche tracée')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrSectionTitle(
                  'COMPTE-RENDU DU TRAVAIL COLLECTIF',
                  icon: Icons.edit_note_outlined,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _textCtrl,
                  minLines: 10,
                  maxLines: 24,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Texte de la planche',
                  ),
                ),
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
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BrColors.text,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
