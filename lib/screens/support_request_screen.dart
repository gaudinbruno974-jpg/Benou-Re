// Demande (Suggestions / Dysfonctionnements) : le V∴M∴ ou le Secrétaire
// signale un bug ou suggère une amélioration. Un PDF « Demande n° X » est
// généré (logo + coordonnées du demandeur), archivé sur le Drive de la Loge
// et envoyé en pièce jointe par Gmail à gaudin.bruno974@gmail.com — voir
// parvis_screen.dart. Le texte de la demande n'est jamais stocké en base,
// seulement dans ce PDF (voir firestore_repository.dart:allocateRequestChrono).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/flavor.dart';
import '../config/lodge_config.dart';
import '../services/drive_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'parvis_screen.dart' show kParvisCardTitles;

const String _kAutre = 'Autre';
const String _kSupportEmail = 'gaudin.bruno974@gmail.com';

/// Catégories du menu « Votre demande concerne » côté Grande Loge : les
/// tuiles de son propre accueil (voir grande_loge_home_screen.dart), pas
/// celles du Parvis d'une loge bleue (kParvisCardTitles), sans objet ici.
const List<String> kGrandeLogeSupportCategories = [
  'Loges Bleues',
  'IAH-MES',
  'MMA-Kherou',
  'Souverain Sanctuaire',
  'Connexion',
];

List<String> get _supportCategories =>
    currentFlavor == 'grandeloge' ? kGrandeLogeSupportCategories : kParvisCardTitles;

class SupportRequestScreen extends StatefulWidget {
  const SupportRequestScreen({super.key});

  @override
  State<SupportRequestScreen> createState() => _SupportRequestScreenState();
}

class _SupportRequestScreenState extends State<SupportRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _menu = _supportCategories.first;
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final user = state.currentUser;
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final lodge = LodgeConfig.current;
    final objet = _menu == _kAutre ? _subjectCtrl.text.trim() : _menu;
    setState(() => _sending = true);
    try {
      final chrono = await state.allocateRequestChrono(_menu);
      final bytes = Uint8List.fromList(
        await buildSupportRequestPdf(
          chrono: chrono,
          objet: objet,
          requester: user,
          message: _messageCtrl.text.trim(),
        ),
      );
      final dateStr = DateFormat('dd MM yy').format(DateTime.now());
      final fileName = 'Demande $chrono ${lodge.name} $dateStr.pdf';
      try {
        await DriveService.instance.archiveSupportRequestDocument(
          fileName: fileName,
          bytes: bytes,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Archivage Drive : $e')),
        );
      }
      await DriveService.instance.sendGmailWithAttachment(
        to: _kSupportEmail,
        subject: 'Demande n°$chrono - ${lodge.name} - $dateStr - $objet',
        body: currentFlavor == 'grandeloge'
            ? 'Nouvelle demande transmise depuis ${lodge.name}.\n\n'
                'Voir le PDF joint pour le détail.'
            : 'Nouvelle demande transmise depuis le Parvis de la R∴L∴ '
                '${lodge.name}.\n\nVoir le PDF joint pour le détail.',
        attachmentName: fileName,
        attachmentBytes: bytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Demande n°$chrono envoyée.'),
          backgroundColor: BrColors.teal,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: BrColors.error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [..._supportCategories, _kAutre];
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions / Dysfonctionnements')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const BrSectionTitle('VOTRE DEMANDE', icon: Icons.support_agent_outlined),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Votre demande concerne',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _menu,
                        isExpanded: true,
                        dropdownColor: BrColors.surface,
                        style: const TextStyle(color: BrColors.text),
                        items: [
                          for (final o in options)
                            DropdownMenuItem(value: o, child: Text(o)),
                        ],
                        onChanged: (v) => setState(() => _menu = v ?? _menu),
                      ),
                    ),
                  ),
                  if (_menu == _kAutre) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _subjectCtrl,
                      style: const TextStyle(color: BrColors.text),
                      decoration: const InputDecoration(labelText: 'Sujet'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Requis'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _messageCtrl,
                    minLines: 5,
                    maxLines: 10,
                    style: const TextStyle(color: BrColors.text),
                    decoration: const InputDecoration(labelText: 'Votre message'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Un PDF est généré, archivé sur le Drive de la Loge et envoyé "
              "par e-mail. Vos coordonnées (fiche membre) y figurent "
              "automatiquement.",
              style: TextStyle(color: BrColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BrColors.text),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}
