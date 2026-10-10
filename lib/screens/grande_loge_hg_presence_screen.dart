// Présences d'une tenue d'un corps de Hauts Grades — même principe que
// session_presence_screen.dart (loges bleues) : membres présents/excusés,
// visiteurs et dignitaires présents, tous avec une case Agapes. Pas de
// « poste pendant la tenue » pour les visiteurs/dignitaires (les offices
// d'une loge bleue — Surveillant, Orateur... — ne s'appliquent pas à un
// Collège de Perfection sans référence pour les remplacer).
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/signature_dialog.dart';
import 'grande_loge_hg_members_screen.dart';

class GrandeLogeHgPresenceScreen extends StatefulWidget {
  final HgBody body;
  final Session session;

  /// Déverrouillage ponctuel d'une tenue suspendue — même mécanique que
  /// SessionPresenceScreen.forceUnlock (loges bleues).
  final bool forceUnlock;

  const GrandeLogeHgPresenceScreen({
    super.key,
    required this.body,
    required this.session,
    this.forceUnlock = false,
  });

  @override
  State<GrandeLogeHgPresenceScreen> createState() =>
      _GrandeLogeHgPresenceScreenState();
}

class _GrandeLogeHgPresenceScreenState
    extends State<GrandeLogeHgPresenceScreen> {
  late List<String> _presentIds;
  late List<String> _excusedIds;
  late List<String> _agapeIds;
  late List<String> _visitorIds;
  late List<String> _visitorAgapeIds;
  late List<String> _dignitaryIds;
  late List<String> _dignitaryAgapeIds;
  late Map<String, String> _signatures;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    _presentIds = List.from(s.presentIds);
    _excusedIds = List.from(s.excusedIds);
    _agapeIds = List.from(s.agapeIds);
    _visitorIds = List.from(s.visitorIds);
    _visitorAgapeIds = List.from(s.visitorAgapeIds);
    _dignitaryIds = List.from(s.dignitaryIds);
    _dignitaryAgapeIds = List.from(s.dignitaryAgapeIds);
    _signatures = Map.from(s.signatures);
  }

  void _togglePresent(String id) {
    setState(() {
      if (_presentIds.contains(id)) {
        _presentIds.remove(id);
      } else {
        _presentIds.add(id);
      }
      _excusedIds.remove(id);
      if (!_presentIds.contains(id)) _agapeIds.remove(id);
    });
  }

  void _toggleExcused(String id) {
    setState(() {
      if (_excusedIds.contains(id)) {
        _excusedIds.remove(id);
      } else {
        _excusedIds.add(id);
      }
      _presentIds.remove(id);
      _agapeIds.remove(id);
    });
  }

  void _toggleAgape(String id) {
    setState(() {
      if (_agapeIds.contains(id)) {
        _agapeIds.remove(id);
      } else {
        _agapeIds.add(id);
      }
    });
  }

  void _toggleVisitor(String id) {
    setState(() {
      if (_visitorIds.contains(id)) {
        _visitorIds.remove(id);
        _visitorAgapeIds.remove(id);
      } else {
        _visitorIds.add(id);
      }
    });
  }

  void _toggleVisitorAndSign(Visitor v) {
    _toggleVisitor(v.id);
    if (_visitorIds.contains(v.id)) _signOnPresent(v.id, v.fullName);
  }

  void _toggleVisitorAgape(String id) {
    setState(() {
      if (_visitorAgapeIds.contains(id)) {
        _visitorAgapeIds.remove(id);
      } else {
        _visitorAgapeIds.add(id);
      }
    });
  }

  void _toggleDignitary(String id) {
    setState(() {
      if (_dignitaryIds.contains(id)) {
        _dignitaryIds.remove(id);
        _dignitaryAgapeIds.remove(id);
      } else {
        _dignitaryIds.add(id);
      }
    });
  }

  void _toggleDignitaryAndSign(Dignitary d) {
    _toggleDignitary(d.id);
    if (_dignitaryIds.contains(d.id)) _signOnPresent(d.id, d.fullName);
  }

  void _toggleDignitaryAgape(String id) {
    setState(() {
      if (_dignitaryAgapeIds.contains(id)) {
        _dignitaryAgapeIds.remove(id);
      } else {
        _dignitaryAgapeIds.add(id);
      }
    });
  }

  Future<void> _persist() async {
    final map = Map<String, dynamic>.from(widget.session.toMap());
    map['presentIds'] = _presentIds;
    map['excusedIds'] = _excusedIds;
    map['agapeIds'] = _agapeIds;
    map['visitorIds'] = _visitorIds;
    map['visitorAgapeIds'] = _visitorAgapeIds;
    map['dignitaryIds'] = _dignitaryIds;
    map['dignitaryAgapeIds'] = _dignitaryAgapeIds;
    map['signatures'] = _signatures;
    final updated = Session.fromMap(widget.session.id, map);
    await HgBodyService.instance.updateSession(widget.body, updated);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _persist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Présences enregistrées.'),
            backgroundColor: BrColors.teal,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Signature proposée automatiquement au pointage « Présent » : ne redemande
  // rien si déjà signé (ex. toggle Présent -> Absent -> Présent).
  Future<void> _signOnPresent(String id, String name) async {
    if (_signatures.containsKey(id)) return;
    final dataUrl = await captureSignature(context, name);
    if (dataUrl == null || !mounted) return;
    setState(() => _signatures[id] = dataUrl);
  }

  // Signature demandée explicitement (badge sur une personne déjà présente) —
  // contrairement à [_signOnPresent], toujours proposée et enregistrée tout
  // de suite, sans attendre le bouton Enregistrer.
  Future<void> _openSignature(String id, String name) async {
    final dataUrl = await captureSignature(context, name);
    if (dataUrl == null || !mounted) return;
    setState(() => _signatures[id] = dataUrl);
    await _persist();
  }

  Widget _dialogField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        style: const TextStyle(color: BrColors.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<Map<String, String>?> _quickPersonForm(
    String heading, {
    required bool withTitle,
  }) async {
    final first = TextEditingController();
    final last = TextEditingController();
    final title = TextEditingController();
    final lodge = TextEditingController();
    final orient = TextEditingController();
    final obedience = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrColors.surface,
        title: Text(heading, style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(first, 'Prénom'),
              _dialogField(last, 'Nom'),
              if (withTitle) _dialogField(title, 'Titre'),
              _dialogField(lodge, 'Loge'),
              _dialogField(orient, 'Orient'),
              _dialogField(obedience, 'Obédience'),
              _dialogField(email, 'Email'),
              _dialogField(phone, 'Téléphone'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return {
      'Prénom': first.text.trim(),
      'Nom': last.text.trim(),
      if (withTitle) 'Titre': title.text.trim(),
      'Loge': lodge.text.trim(),
      'Orient': orient.text.trim(),
      'Obédience': obedience.text.trim(),
      'Email': email.text.trim(),
      'Téléphone': phone.text.trim(),
    };
  }

  Future<void> _addMember() async {
    final member = await Navigator.of(context).push<Member>(
      MaterialPageRoute<Member>(
        builder: (_) => GrandeLogeHgMemberEditScreen(body: widget.body),
      ),
    );
    if (member == null || !mounted) return;
    setState(() => _presentIds.add(member.id));
    await _signOnPresent(member.id, member.fullName);
    if (mounted) await _persist();
  }

  Future<void> _addVisitor() async {
    final f = await _quickPersonForm('Nouveau visiteur', withTitle: false);
    if (f == null || (f['Prénom']!.isEmpty && f['Nom']!.isEmpty)) return;
    final id = 'v_${DateTime.now().millisecondsSinceEpoch}';
    final visitor = Visitor(
      id: id,
      firstName: f['Prénom']!,
      lastName: f['Nom']!,
      lodge: f['Loge']!,
      orient: f['Orient']!,
      obedience: f['Obédience']!,
      email: f['Email']!,
      phone: f['Téléphone']!,
    );
    await HgBodyService.instance.saveVisitor(widget.body, visitor);
    if (!mounted) return;
    setState(() => _visitorIds.add(id));
    await _signOnPresent(id, visitor.fullName);
    if (mounted) await _persist();
  }

  Future<void> _addDignitary() async {
    final f = await _quickPersonForm('Nouveau dignitaire', withTitle: true);
    if (f == null || (f['Prénom']!.isEmpty && f['Nom']!.isEmpty)) return;
    final id = 'd_${DateTime.now().millisecondsSinceEpoch}';
    final dignitary = Dignitary(
      id: id,
      firstName: f['Prénom']!,
      lastName: f['Nom']!,
      title: f['Titre']!,
      lodge: f['Loge']!,
      orient: f['Orient']!,
      obedience: f['Obédience']!,
      email: f['Email']!,
      phone: f['Téléphone']!,
    );
    await HgBodyService.instance.saveDignitary(widget.body, dignitary);
    if (!mounted) return;
    setState(() => _dignitaryIds.add(id));
    await _signOnPresent(id, dignitary.fullName);
    if (mounted) await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final allowEdit = !widget.session.isSuspended || widget.forceUnlock;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Présence'),
        actions: [
          if (allowEdit)
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
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          if (!allowEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Tenue suspendue : lecture seule.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          Row(
            children: [
              const Expanded(
                child: BrSectionTitle(
                  'MEMBRES — PRÉSENTS / EXCUSÉS / AGAPES',
                  icon: Icons.people_outline,
                ),
              ),
              if (allowEdit)
                TextButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 16,
                    color: BrColors.teal,
                  ),
                  label: const Text(
                    'Ajouter',
                    style: TextStyle(color: BrColors.teal, fontSize: 12),
                  ),
                ),
            ],
          ),
          StreamBuilder<List<Member>>(
            stream: HgBodyService.instance.membersStream(widget.body),
            builder: (context, snap) {
              final allMembers = snap.data ?? const [];
              // IAH-MES uniquement (échelle 4°-14°, MAA-Kherou n'a pas
              // cette notion de degré) : même règle que les convocations et
              // le choix d'un auteur de planche.
              final members = widget.body.key == kIahMes.key
                  ? allMembers.where((m) {
                      final sessionDegree =
                          int.tryParse(
                            widget.session.degreTravail ??
                                widget.session.degree,
                          ) ??
                          0;
                      final memberDegree =
                          int.tryParse(m.hautsGradesDegree) ?? 0;
                      return memberDegree >= sessionDegree;
                    }).toList()
                  : allMembers;
              if (members.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Aucun membre.',
                    style: TextStyle(color: BrColors.muted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in members)
                    _PresenceTile(
                      name: m.fullName,
                      subtitle: m.function.isNotEmpty && m.function != 'Aucun'
                          ? m.function
                          : 'Membre',
                      isPresent: _presentIds.contains(m.id),
                      isExcused: _excusedIds.contains(m.id),
                      isAgape: _agapeIds.contains(m.id),
                      signed: _signatures.containsKey(m.id),
                      onPresent: allowEdit
                          ? () {
                              _togglePresent(m.id);
                              if (_presentIds.contains(m.id)) {
                                _signOnPresent(m.id, m.fullName);
                              }
                            }
                          : null,
                      onExcused: allowEdit ? () => _toggleExcused(m.id) : null,
                      onAgape: allowEdit ? () => _toggleAgape(m.id) : null,
                      onSign: allowEdit
                          ? () => _openSignature(m.id, m.fullName)
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: BrSectionTitle(
                  'VISITEURS — PRÉSENTS / AGAPES',
                  icon: Icons.shield_outlined,
                ),
              ),
              if (allowEdit)
                TextButton.icon(
                  onPressed: _addVisitor,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 16,
                    color: BrColors.teal,
                  ),
                  label: const Text(
                    'Ajouter',
                    style: TextStyle(color: BrColors.teal, fontSize: 12),
                  ),
                ),
            ],
          ),
          StreamBuilder<List<Visitor>>(
            stream: HgBodyService.instance.visitorsStream(widget.body),
            builder: (context, snap) {
              final visitors = snap.data ?? const [];
              if (visitors.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Aucun visiteur.',
                    style: TextStyle(color: BrColors.muted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final v in visitors)
                    _PresenceTile(
                      name: v.fullName,
                      subtitle: [
                        v.lodge,
                        v.orient,
                      ].where((e) => e.isNotEmpty).join(' — '),
                      isPresent: _visitorIds.contains(v.id),
                      isExcused: false,
                      isAgape: _visitorAgapeIds.contains(v.id),
                      signed: _signatures.containsKey(v.id),
                      onPresent: allowEdit
                          ? () => _toggleVisitorAndSign(v)
                          : null,
                      onExcused: null,
                      onAgape: allowEdit
                          ? () => _toggleVisitorAgape(v.id)
                          : null,
                      onSign: allowEdit
                          ? () => _openSignature(v.id, v.fullName)
                          : null,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: BrSectionTitle(
                  'DIGNITAIRES — PRÉSENTS / AGAPES',
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              if (allowEdit)
                TextButton.icon(
                  onPressed: _addDignitary,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 16,
                    color: BrColors.teal,
                  ),
                  label: const Text(
                    'Ajouter',
                    style: TextStyle(color: BrColors.teal, fontSize: 12),
                  ),
                ),
            ],
          ),
          StreamBuilder<List<Dignitary>>(
            stream: HgBodyService.instance.dignitariesStream(widget.body),
            builder: (context, snap) {
              final dignitaries = snap.data ?? const [];
              if (dignitaries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Aucun dignitaire.',
                    style: TextStyle(color: BrColors.muted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final d in dignitaries)
                    _PresenceTile(
                      name: d.fullName,
                      subtitle: [
                        d.title,
                        d.lodge,
                      ].where((e) => e.isNotEmpty).join(' — '),
                      isPresent: _dignitaryIds.contains(d.id),
                      isExcused: false,
                      isAgape: _dignitaryAgapeIds.contains(d.id),
                      signed: _signatures.containsKey(d.id),
                      onPresent: allowEdit
                          ? () => _toggleDignitaryAndSign(d)
                          : null,
                      onExcused: null,
                      onAgape: allowEdit
                          ? () => _toggleDignitaryAgape(d.id)
                          : null,
                      onSign: allowEdit
                          ? () => _openSignature(d.id, d.fullName)
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PresenceTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isPresent;
  final bool isExcused;
  final bool isAgape;
  final bool signed;
  final VoidCallback? onPresent;
  final VoidCallback? onExcused;
  final VoidCallback? onAgape;
  final VoidCallback? onSign;
  const _PresenceTile({
    required this.name,
    required this.subtitle,
    required this.isPresent,
    required this.isExcused,
    required this.isAgape,
    required this.signed,
    required this.onPresent,
    required this.onExcused,
    required this.onAgape,
    required this.onSign,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: isPresent
            ? const Color(0xFF34D399)
            : isExcused
            ? BrColors.gold
            : BrColors.muted,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                BrAvatar(
                  firstName: name.split(' ').first,
                  lastName: name.split(' ').length > 1
                      ? name.split(' ').last
                      : '',
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: BrColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _Chip(
                  label: 'Présent',
                  selected: isPresent,
                  color: const Color(0xFF34D399),
                  onTap: onPresent,
                ),
                if (onExcused != null) ...[
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Excusé',
                    selected: isExcused,
                    color: BrColors.gold,
                    onTap: onExcused,
                  ),
                ],
              ],
            ),
            if (isPresent)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SignatureBadge(signed: signed, onTap: onSign),
                    _Chip(
                      label: 'Agapes',
                      selected: isAgape,
                      color: BrColors.teal,
                      onTap: onAgape,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SignatureBadge extends StatelessWidget {
  final bool signed;
  final VoidCallback? onTap;
  const _SignatureBadge({required this.signed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = signed ? const Color(0xFF34D399) : BrColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              signed ? Icons.check_circle_outline : Icons.schedule,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              signed ? 'Signé' : 'Signature en attente',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : BrColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : BrColors.muted.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0C2A3E) : BrColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
