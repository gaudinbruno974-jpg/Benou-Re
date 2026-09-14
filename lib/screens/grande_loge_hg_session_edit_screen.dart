// Formulaire de tenue pour IAH-MES — seuls les champs qui varient d'une
// tenue à l'autre sont saisis, le reste de la convocation est figé (voir
// hg_pdf_service.dart).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgSessionEditScreen extends StatefulWidget {
  final HgBody body;
  final HgSession? session;
  const GrandeLogeHgSessionEditScreen({
    super.key,
    required this.body,
    this.session,
  });

  @override
  State<GrandeLogeHgSessionEditScreen> createState() =>
      _GrandeLogeHgSessionEditScreenState();
}

class _GrandeLogeHgSessionEditScreenState
    extends State<GrandeLogeHgSessionEditScreen> {
  DateTime? _date;
  late final TextEditingController _heureCtrl;
  late int _degree;
  late final TextEditingController _lieuCtrl;
  late final TextEditingController _themeTitleCtrl;
  late final TextEditingController _themeTextCtrl;
  late final TextEditingController _agapePriceCtrl;
  late final TextEditingController _signerCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _date = s?.dateTime;
    _heureCtrl = TextEditingController(text: s?.heure ?? '19H30');
    _degree = s?.degree ?? 4;
    _lieuCtrl = TextEditingController(text: s?.lieu ?? '');
    _themeTitleCtrl = TextEditingController(text: s?.themeTitle ?? '');
    _themeTextCtrl = TextEditingController(text: s?.themeText ?? '');
    _agapePriceCtrl = TextEditingController(
      text: (s?.agapePrice ?? 15).toString(),
    );
    _signerCtrl = TextEditingController(
      text: s?.signerName ?? 'Jean-Pierre T∴',
    );
  }

  @override
  void dispose() {
    _heureCtrl.dispose();
    _lieuCtrl.dispose();
    _themeTitleCtrl.dispose();
    _themeTextCtrl.dispose();
    _agapePriceCtrl.dispose();
    _signerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_date == null) return;
    setState(() => _saving = true);
    try {
      final session = HgSession(
        id: widget.session?.id ?? '',
        date: _date!.toIso8601String(),
        heure: _heureCtrl.text.trim(),
        degree: _degree,
        lieu: _lieuCtrl.text.trim(),
        themeTitle: _themeTitleCtrl.text.trim(),
        themeText: _themeTextCtrl.text.trim(),
        agapePrice: num.tryParse(_agapePriceCtrl.text.trim()) ?? 15,
        signerName: _signerCtrl.text.trim(),
      );
      await HgBodyService.instance.saveSession(widget.body, session);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session == null ? 'Nouvelle tenue' : 'Modifier la tenue',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(
                      _date == null
                          ? 'Choisir'
                          : DateFormat('EEEE d MMMM y', 'fr_FR').format(_date!),
                      style: const TextStyle(color: BrColors.text),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _heureCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Heure (ex : 19H30)',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _degree,
                  decoration: const InputDecoration(labelText: 'Degré'),
                  items: [
                    for (final entry in kIahMesDegreeNames.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text('${entry.key}e degré — ${entry.value}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _degree = v ?? _degree),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _lieuCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    hintText:
                        'Temple Thérèse Eliseman, à l\'Orient de Saint-Pierre',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrSectionTitle(
                  'THÈME DE LA TENUE',
                  icon: Icons.auto_stories_outlined,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _themeTitleCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Titre'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _themeTextCtrl,
                  minLines: 3,
                  maxLines: 8,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(labelText: 'Texte'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _agapePriceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Participation aux agapes (€)',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _signerCtrl,
                  style: const TextStyle(color: BrColors.text),
                  decoration: const InputDecoration(
                    labelText: 'Trois Fois Puissant Maître (signataire)',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: (_saving || _date == null) ? null : _save,
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
