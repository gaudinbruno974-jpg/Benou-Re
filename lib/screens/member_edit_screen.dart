// Création / édition d'un membre.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/civilite.dart';
import '../models/member.dart';
import '../models/preferred_contact.dart';
import '../services/drive_service.dart';
import '../services/member_account_service.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'member_history_section.dart';

class MemberEditScreen extends StatefulWidget {
  final Member? member;
  const MemberEditScreen({super.key, this.member});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls;
  late String _grade;
  late String _status;
  late String _function;
  late String _civilite;
  late String _preferredContact;
  late List<String> _functions;
  bool _saving = false;
  bool _inviting = false;
  bool _passportBusy = false;

  static const _grades = kGrades;
  static const _statuses = [
    'Actif',
    'Honoraire',
    'En sommeil',
    'Démissionnaire',
    'Radié'
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _ctrls = {
      'firstName': TextEditingController(text: m?.firstName ?? ''),
      'lastName': TextEditingController(text: m?.lastName ?? ''),
      'email': TextEditingController(text: m?.email ?? ''),
      'phone': TextEditingController(text: m?.phone ?? ''),
      'address': TextEditingController(text: m?.address ?? ''),
      'matricule': TextEditingController(text: m?.matricule ?? ''),
      'motherLodge': TextEditingController(text: m?.motherLodge ?? ''),
      'sponsor': TextEditingController(text: m?.sponsor ?? ''),
      'birthDate': TextEditingController(text: m?.birthDate ?? ''),
      'initiationDate': TextEditingController(text: m?.initiationDate ?? ''),
      'entryDate': TextEditingController(text: m?.entryDate ?? ''),
      'lodgeDues': TextEditingController(text: '${m?.lodgeDues ?? 0}'),
      'orderDues': TextEditingController(text: '${m?.orderDues ?? 0}'),
      'hautsGradesDegree':
          TextEditingController(text: m?.hautsGradesDegree ?? ''),
    };
    _grade = normalizeGrade(m?.grade ?? kApprenti);
    _status = m?.status ?? 'Actif';
    _civilite = m?.civilite ?? '';
    _preferredContact = m?.preferredContact ?? '';
    _function = (m?.function ?? '').trim().isEmpty
        ? kFunctions.first
        : m!.function.trim();
    // Un office hérité hors liste reste proposé, pour ne pas l'effacer à
    // l'enregistrement.
    _functions = kFunctions.contains(_function)
        ? kFunctions
        : [...kFunctions, _function];
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final existing = widget.member;
    final id = existing?.id ??
        'm_${DateTime.now().millisecondsSinceEpoch}';
    final base = existing ?? Member(id: id);
    final lodgeDues = num.tryParse(_ctrls['lodgeDues']!.text) ?? 0;
    final orderDues = num.tryParse(_ctrls['orderDues']!.text) ?? 0;
    // Les montants saisis ici concernent l'année courante.
    final year = DateTime.now().year;
    final currentDues = base.duesFor(year).copyWith(
          lodgeDues: lodgeDues,
          orderDues: orderDues,
        );
    final member = base
        .copyWith(
          firstName: _ctrls['firstName']!.text.trim(),
          lastName: _ctrls['lastName']!.text.trim(),
          email: _ctrls['email']!.text.trim(),
          phone: _ctrls['phone']!.text.trim(),
          address: _ctrls['address']!.text.trim(),
          matricule: _ctrls['matricule']!.text.trim(),
          birthDate: _ctrls['birthDate']!.text.trim(),
          initiationDate: _ctrls['initiationDate']!.text.trim(),
          entryDate: _ctrls['entryDate']!.text.trim(),
          function: _function,
          civilite: _civilite,
          preferredContact: _preferredContact,
          motherLodge: _ctrls['motherLodge']!.text.trim(),
          sponsor: _ctrls['sponsor']!.text.trim(),
          grade: _grade,
          status: _status,
          lodgeDues: lodgeDues,
          orderDues: orderDues,
          hautsGradesDegree: _ctrls['hautsGradesDegree']!.text.trim(),
        )
        .withDuesForYear(year, currentDues);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (existing == null) {
        await state.addMember(member);
        // Compte de connexion « best effort » : son échec ne doit pas empêcher
        // l'enregistrement de la fiche.
        if (member.email.isNotEmpty) {
          try {
            final result =
                await MemberAccountService.instance.invite(member.email);
            await state.updateMember(member.copyWith(
              loginEmail: member.email,
              authUid: result.uid ?? member.authUid,
            ));
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  result.status == MemberAccountStatus.created
                      ? 'Invitation envoyée à ${member.email} : le membre définit son mot de passe par e-mail.'
                      : '${member.email} avait déjà un compte : e-mail de mot de passe renvoyé.',
                ),
                backgroundColor: BrColors.teal,
              ),
            );
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Invitation non envoyée : $e'),
                backgroundColor: BrColors.error,
              ),
            );
          }
        }
      } else {
        await state.updateMember(member);
      }
      if (mounted) navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Envoie (ou renvoie) l'invitation à l'adresse de connexion. Quand
  /// [newLoginEmail] est vrai, cette adresse devient le nouvel identifiant de
  /// connexion du membre.
  Future<void> _sendInvitation(String email,
      {bool newLoginEmail = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    final member = widget.member;
    setState(() => _inviting = true);
    try {
      final result = await MemberAccountService.instance.invite(email);
      if (newLoginEmail && member != null) {
        await state.updateMember(member.copyWith(
          loginEmail: email,
          authUid: result.uid ?? '',
        ));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.status == MemberAccountStatus.created
                ? 'Compte créé et invitation envoyée à $email.'
                : 'Invitation renvoyée à $email.',
          ),
          backgroundColor: BrColors.teal,
        ),
      );
      if (newLoginEmail && mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invitation non envoyée : $e'),
          backgroundColor: BrColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  /// Demande la nouvelle adresse de connexion et confirme la bascule :
  /// l'ancien compte deviendra inutilisable.
  Future<void> _askNewLoginEmail() async {
    final ctrl = TextEditingController(text: _ctrls['email']!.text.trim());
    final address = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: const Text("Changer l'e-mail de connexion"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Un compte sera créé à la nouvelle adresse et le membre recevra "
              "une invitation. Son ancien compte de connexion deviendra "
              "inutilisable.",
              style: TextStyle(color: BrColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: const TextStyle(color: BrColors.text),
              decoration: const InputDecoration(
                labelText: 'Nouvel e-mail de connexion',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (address == null || address.isEmpty) return;
    await _sendInvitation(address, newLoginEmail: true);
  }

  /// Génère le Passeport Maçonnique (PDF, sans QR) et l'archive sur Drive —
  /// réservé au bureau, pour n'importe quelle fiche (voir _passportSection).
  Future<void> _generatePassportPdf() async {
    final member = widget.member;
    if (member == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final state = context.read<AppState>();
    setState(() => _passportBusy = true);
    try {
      final bytes = Uint8List.fromList(
        await buildPassportPdf(
          member,
          state.members,
          lodgeVmName: state.lodgeVmName,
        ),
      );
      final fileName = 'Passeport GLDB ${LodgeConfig.current.name} - '
          '${member.lastName} ${member.firstName}.pdf';
      try {
        await DriveService.instance.archivePassportDocument(
          fileName: fileName,
          bytes: bytes,
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Archivage Drive : $e')),
        );
      }
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur PDF : $e')));
    } finally {
      if (mounted) setState(() => _passportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.member == null;
    final loginEmail = widget.member?.effectiveLoginEmail ?? '';
    final currentUser = context.watch<AppState>().currentUser;
    final canManageAccount = !isNew && canEditSessions(currentUser);
    final canInvite = canManageAccount && loginEmail.isNotEmpty;
    // Le PDF (archive) reste au bureau, sur n'importe quelle fiche : le QR de
    // vérification, lui, n'a de sens que généré par l'intéressé lui-même —
    // voir le bouton dédié sur sa propre ligne dans members_screen.dart.
    final canGeneratePassportPdf = canManageAccount;
    final canSeeHautsGrades = canViewHautsGrades(currentUser);
    return Scaffold(
      appBar: AppBar(
          title: Text(isNew ? 'Nouveau membre' : 'Modifier le membre')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const BrSectionTitle('IDENTITÉ', icon: Icons.badge_outlined),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('firstName', 'Prénom', required: true),
                  _field('lastName', 'Nom', required: true),
                  _field('email', 'Email de contact',
                      keyboard: TextInputType.emailAddress),
                  _field('phone', 'Téléphone', keyboard: TextInputType.phone),
                  _field('address', 'Adresse'),
                  _dateField('birthDate', 'Date de naissance', last: true),
                  const SizedBox(height: 14),
                  _dropdown(
                    'Canal préféré',
                    _preferredContact,
                    const ['', ...kPreferredContacts],
                    (v) => setState(() => _preferredContact = v),
                    labelBuilder: (c) => c.isEmpty ? 'Vide' : c,
                  ),
                ],
              ),
            ),
            if (!isNew) ...[
              const SizedBox(height: 24),
              const BrSectionTitle('CONNEXION', icon: Icons.lock_outline),
              const SizedBox(height: 14),
              BrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      loginEmail.isEmpty
                          ? 'Aucun compte de connexion.'
                          : loginEmail,
                      style: const TextStyle(color: BrColors.text),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Identifiant de connexion du membre. Modifier l'e-mail de "
                      "contact ci-dessus ne le change pas.",
                      style: TextStyle(color: BrColors.muted, fontSize: 11),
                    ),
                    if (canManageAccount) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _inviting ? null : _askNewLoginEmail,
                        icon: const Icon(Icons.alternate_email),
                        label: const Text("Changer l'e-mail de connexion"),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (!isNew && canGeneratePassportPdf) ...[
              const SizedBox(height: 24),
              const BrSectionTitle('PASSEPORT MAÇONNIQUE',
                  icon: Icons.badge_outlined),
              const SizedBox(height: 14),
              BrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Générer le PDF (archive Drive)'),
                      onPressed: _passportBusy ? null : _generatePassportPdf,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Document d'archive/impression, sans QR : le QR de "
                      'vérification se génère uniquement par le membre '
                      'lui-même, depuis sa propre ligne dans « Membres ».',
                      style: TextStyle(color: BrColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            const BrSectionTitle('PARCOURS MAÇONNIQUE',
                icon: Icons.auto_awesome),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('matricule', 'Matricule'),
                  _field('motherLodge', 'Loge mère'),
                  _field('sponsor', 'Parrain'),
                  _dateField('initiationDate', "Date d'initiation"),
                  _dateField('entryDate', "Date d'entrée", last: true),
                  const SizedBox(height: 14),
                  _dropdown('Office / Fonction', _function, _functions,
                      (v) => setState(() => _function = v)),
                  const SizedBox(height: 14),
                  _dropdown(
                    'Civilité',
                    _civilite,
                    const ['', ...kCivilites],
                    (v) => setState(() => _civilite = v),
                    labelBuilder: (c) => c.isEmpty ? 'Non renseignée' : c,
                  ),
                  const SizedBox(height: 14),
                  _dropdown('Grade', _grade, _grades,
                      (v) => setState(() => _grade = v)),
                  const SizedBox(height: 14),
                  _dropdown('Statut', _status, _statuses,
                      (v) => setState(() => _status = v)),
                ],
              ),
            ),
            if (canSeeHautsGrades) ...[
              const SizedBox(height: 24),
              const BrSectionTitle('HAUTS GRADES', icon: Icons.stars_outlined),
              const SizedBox(height: 14),
              BrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('hautsGradesDegree', 'Degré', last: true),
                    const SizedBox(height: 6),
                    const Text(
                      'Axe séparé du grade de loge bleue ci-dessus. Réservé à '
                      "l'administrateur : jamais visible ni exporté côté loge "
                      'bleue.',
                      style: TextStyle(color: BrColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            if (!isNew && canGeneratePassportPdf) ...[
              const SizedBox(height: 24),
              const BrSectionTitle('HISTORIQUE', icon: Icons.history),
              const SizedBox(height: 14),
              MemberHistorySection(
                member: widget.member!,
                grades: _grades,
                statuses: _statuses,
              ),
            ],
            const SizedBox(height: 24),
            const BrSectionTitle('COTISATIONS',
                icon: Icons.account_balance_wallet_outlined),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('lodgeDues', 'Cotisation Loge (€)',
                      keyboard: TextInputType.number),
                  _field('orderDues', 'Cotisation Ordre (€)',
                      keyboard: TextInputType.number, last: true),
                ],
              ),
            ),
            const SizedBox(height: 26),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: BrColors.text))
                  : const Icon(Icons.save),
              label: const Text('Enregistrer'),
            ),
            if (canInvite) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _inviting ? null : () => _sendInvitation(loginEmail),
                icon: _inviting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: BrColors.text))
                    : const Icon(Icons.mail_outline),
                label: const Text("Renvoyer l'invitation"),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Envoie au membre un e-mail lui permettant de définir son mot de passe de connexion.",
                  style: TextStyle(color: BrColors.muted, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label,
      {bool required = false, TextInputType? keyboard, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: _ctrls[key],
        keyboardType: keyboard,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
            : null,
      ),
    );
  }

  /// Champ de date : saisie libre (compatible avec les valeurs importées
  /// d'un classeur .xlsx, qui ne sont pas forcément au format jj/mm/aaaa) ou
  /// sélection via le calendrier, qui écrit alors ce format.
  Widget _dateField(String key, String label, {bool last = false}) {
    final ctrl = _ctrls[key]!;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: ctrl,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            onPressed: () async {
              DateTime initial;
              try {
                initial = DateFormat('dd/MM/yyyy').parseStrict(
                  ctrl.text.trim(),
                );
              } catch (_) {
                initial = DateTime.now();
              }
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
              }
            },
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
                child: Text(labelBuilder == null ? o : labelBuilder(o)),
              ),
          ],
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }
}
