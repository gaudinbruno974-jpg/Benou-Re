// Enregistrement/modification d'une invitation reçue pour une Tenue
// extérieure (Registre des Tenues extérieures, Bureau) — formulaire
// volontairement rapide : seuls la Loge organisatrice et la date sont
// obligatoires. Réservé au Vénérable Maître, au Secrétaire et aux
// administrateurs (canEditSessions), même droit que pour créer/modifier une
// tenue de la Loge.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/external_session.dart';
import '../services/drive_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

class ExternalSessionEditScreen extends StatefulWidget {
  final ExternalSession? session;
  const ExternalSessionEditScreen({super.key, this.session});

  @override
  State<ExternalSessionEditScreen> createState() =>
      _ExternalSessionEditScreenState();
}

class _ExternalSessionEditScreenState
    extends State<ExternalSessionEditScreen> {
  late final TextEditingController _lodge;
  late final TextEditingController _obedience;
  late final TextEditingController _location;
  late final TextEditingController _eventTypeOther;
  late final TextEditingController _notes;
  DateTime? _dateTime;
  late String _degree;
  late String _eventType;
  late String _contactPerson;
  bool _saving = false;

  // Pièce jointe : soit celle déjà archivée (édition), soit un nouveau
  // fichier choisi sur cet écran, pas encore uploadé tant que « Enregistrer »
  // n'a pas été validé.
  String _existingAttachmentName = '';
  String _existingAttachmentUrl = '';
  String _existingAttachmentFileId = '';
  String _existingAttachmentContentType = '';
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _lodge = TextEditingController(text: s?.organizingLodge ?? '');
    _obedience = TextEditingController(text: s?.obedience ?? 'GLDB');
    _location = TextEditingController(text: s?.location ?? '');
    _eventTypeOther = TextEditingController(text: s?.eventTypeOther ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _dateTime = s?.dateTime;
    _degree = s?.degree ?? kExternalDegreeAll;
    _eventType = s?.eventType ?? kExternalEventOrdinaire;
    _contactPerson = s?.contactPerson ?? kExternalContactSecretaire;
    _existingAttachmentName = s?.attachmentFileName ?? '';
    _existingAttachmentUrl = s?.attachmentDriveUrl ?? '';
    _existingAttachmentFileId = s?.attachmentFileId ?? '';
    _existingAttachmentContentType = s?.attachmentContentType ?? '';
  }

  @override
  void dispose() {
    _lodge.dispose();
    _obedience.dispose();
    _location.dispose();
    _eventTypeOther.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _canSave => _lodge.text.trim().isNotEmpty && _dateTime != null;

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('fr', 'FR'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dateTime != null
          ? TimeOfDay(hour: _dateTime!.hour, minute: _dateTime!.minute)
          : const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFile = result.files.single);
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/pdf';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    var attachmentName = _existingAttachmentName;
    var attachmentUrl = _existingAttachmentUrl;
    var attachmentFileId = _existingAttachmentFileId;
    var attachmentContentType = _existingAttachmentContentType;
    final picked = _pickedFile;
    if (picked != null && picked.bytes != null) {
      try {
        final contentType = _contentTypeFor(picked.name);
        final archived = await DriveService.instance.archiveExternalSessionAttachment(
          fileName: picked.name,
          bytes: Uint8List.fromList(picked.bytes!),
          contentType: contentType,
        );
        attachmentUrl = archived.url;
        attachmentFileId = archived.fileId;
        attachmentContentType = contentType;
        attachmentName = picked.name;
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Archivage Drive : $e')));
      }
    }

    final existing = widget.session;
    final id = existing?.id ?? 'ext_${DateTime.now().millisecondsSinceEpoch}';
    final result = ExternalSession(
      id: id,
      organizingLodge: _lodge.text.trim(),
      obedience: _obedience.text.trim(),
      date: _dateTime!.toIso8601String(),
      location: _location.text.trim(),
      degree: _degree,
      eventType: _eventType,
      eventTypeOther: _eventTypeOther.text.trim(),
      contactPerson: _contactPerson,
      notes: _notes.text.trim(),
      attachmentFileName: attachmentName,
      attachmentDriveUrl: attachmentUrl,
      attachmentFileId: attachmentFileId,
      attachmentContentType: attachmentContentType,
      attendingMemberIds: existing?.attendingMemberIds ?? const [],
    );

    try {
      if (existing == null) {
        await state.addExternalSession(result);
      } else {
        await state.updateExternalSession(result);
      }
      if (mounted) navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isNew = widget.session == null;
    final lodgeSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.lodge,
      for (final d in state.dignitaries) d.lodge,
      for (final e in state.externalSessions) e.organizingLodge,
    ]);
    final obedienceSuggestions = distinctSuggestions([
      for (final v in state.visitors) v.obedience,
      for (final d in state.dignitaries) d.obedience,
      for (final e in state.externalSessions) e.obedience,
    ]);
    final locationSuggestions = distinctSuggestions([
      for (final e in state.externalSessions) e.location,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Invitation reçue' : 'Modifier l\'invitation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          DirectoryAutocompleteField(
            controller: _lodge,
            label: 'Loge organisatrice *',
            suggestions: lodgeSuggestions,
          ),
          DirectoryAutocompleteField(
            controller: _obedience,
            label: 'Obédience',
            suggestions: obedienceSuggestions,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date et heure *'),
              child: Text(
                _dateTime == null
                    ? 'Choisir'
                    : DateFormat('EEEE d MMM y à HH:mm', 'fr_FR').format(_dateTime!),
                style: TextStyle(
                  color: _dateTime == null ? BrColors.muted : BrColors.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          DirectoryAutocompleteField(
            controller: _location,
            label: 'Lieu',
            suggestions: locationSuggestions,
          ),
          _dropdown(
            'Degré concerné',
            _degree,
            kExternalDegrees,
            (v) => setState(() => _degree = v),
          ),
          const SizedBox(height: 14),
          _dropdown(
            'Type d\'événement',
            _eventType,
            kExternalEventTypes,
            (v) => setState(() => _eventType = v),
          ),
          if (_eventType == kExternalEventAutre) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _eventTypeOther,
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(labelText: 'Préciser le type'),
            ),
          ],
          const SizedBox(height: 14),
          _dropdown(
            'Contact pour réponse',
            _contactPerson,
            const [kExternalContactSecretaire, kExternalContactVenerable],
            (v) => setState(() => _contactPerson = v),
            labelBuilder: (v) =>
                v == kExternalContactVenerable ? 'Vénérable Maître' : 'Secrétaire',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 3,
            style: const TextStyle(color: BrColors.text),
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          BrCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carton d\'invitation (photo ou PDF)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _pickedFile?.name ??
                      (_existingAttachmentName.isEmpty
                          ? 'Aucun fichier'
                          : _existingAttachmentName),
                  style: const TextStyle(color: BrColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    _existingAttachmentName.isEmpty && _pickedFile == null
                        ? 'Choisir un fichier'
                        : 'Remplacer le fichier',
                  ),
                  onPressed: _pickAttachment,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
            onPressed: _canSave && !_saving ? _save : null,
          ),
        ],
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
              DropdownMenuItem(
                value: o,
                child: Text(labelBuilder != null ? labelBuilder(o) : o),
              ),
          ],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}
