// Création / édition d'un membre.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/civilite.dart';
import '../models/member.dart';
import '../services/member_account_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

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
  late List<String> _functions;
  bool _saving = false;
  bool _inviting = false;

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
      'lodgeDues': TextEditingController(text: '${m?.lodgeDues ?? 0}'),
      'orderDues': TextEditingController(text: '${m?.orderDues ?? 0}'),
    };
    _grade = normalizeGrade(m?.grade ?? kApprenti);
    _status = m?.status ?? 'Actif';
    _civilite = m?.civilite ?? '';
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
          function: _function,
          civilite: _civilite,
          motherLodge: _ctrls['motherLodge']!.text.trim(),
          sponsor: _ctrls['sponsor']!.text.trim(),
          grade: _grade,
          status: _status,
          lodgeDues: lodgeDues,
          orderDues: orderDues,
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

  @override
  Widget build(BuildContext context) {
    final isNew = widget.member == null;
    final loginEmail = widget.member?.effectiveLoginEmail ?? '';
    final canManageAccount =
        !isNew && canEditSessions(context.watch<AppState>().currentUser);
    final canInvite = canManageAccount && loginEmail.isNotEmpty;
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
                  _field('address', 'Adresse', last: true),
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
            const SizedBox(height: 24),
            const BrSectionTitle('PARCOURS MAÇONNIQUE',
                icon: Icons.auto_awesome),
            const SizedBox(height: 14),
            BrCard(
              child: Column(
                children: [
                  _field('matricule', 'Matricule'),
                  _field('motherLodge', 'Loge mère'),
                  _field('sponsor', 'Parrain', last: true),
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
