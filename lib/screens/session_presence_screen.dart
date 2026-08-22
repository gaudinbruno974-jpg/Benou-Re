// Gestion des présences d'une tenue (porté depuis
// src/components/SessionPresenceScreen.tsx).
//
// Trois panneaux :
//  - MEMBRES : boutons « Présent » / « Excusé » mutuellement exclusifs
//    (gèrent session.presentIds / session.excusedIds).
//  - VISITEURS : toggle « Présent » / « Absent » (gère session.visitorIds) ;
//    lorsqu'il est présent, un menu déroulant « Poste pendant la tenue »
//    écrit dans session.visitorRoles[visitorId].
//  - DIGNITAIRES : même mécanisme que les visiteurs (session.dignitaryIds /
//    session.dignitaryRoles / session.dignitaryAgapeIds).
//
// L'enregistrement persiste ces champs via AppState.updateSession, sans
// toucher au reste de la tenue.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import '../widgets/directory_filter.dart';

// Liste des offices pouvant être pris pendant la tenue par un visiteur ou un
// dignitaire, partagée entre les deux (voir _officePlacement dans
// pdf_service.dart pour le placement rituel associé à chaque office).
const _officeRoleOptions = [
  'Premier Surveillant',
  'Second Surveillant',
  'Orateur',
  'Secrétaire',
  'Trésorier',
  'Hospitalier',
  'Maître des Cérémonies',
  'Couvreur',
  "Maître de l'Harmonie",
  'à l’Orient',
  'Colonne du Septentrion',
  'Colonne du midi',
];

class SessionPresenceScreen extends StatefulWidget {
  final String sessionId;
  const SessionPresenceScreen({super.key, required this.sessionId});

  @override
  State<SessionPresenceScreen> createState() => _SessionPresenceScreenState();
}

class _SessionPresenceScreenState extends State<SessionPresenceScreen> {
  late List<String> _presentIds;
  late List<String> _excusedIds;
  late List<String> _visitorIds;
  late Map<String, String> _visitorRoles;
  late List<String> _dignitaryIds;
  late Map<String, String> _dignitaryRoles;
  late List<String> _agapeIds;
  late List<String> _visitorAgapeIds;
  late List<String> _dignitaryAgapeIds;
  bool _initialized = false;
  bool _saving = false;

  final _visitorSearch = TextEditingController();
  DirectoryGroupMode _visitorMode = DirectoryGroupMode.all;
  final _dignitarySearch = TextEditingController();
  DirectoryGroupMode _dignitaryMode = DirectoryGroupMode.all;

  @override
  void initState() {
    super.initState();
    _visitorSearch.addListener(() => setState(() {}));
    _dignitarySearch.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _visitorSearch.dispose();
    _dignitarySearch.dispose();
    super.dispose();
  }

  void _initFrom(Session session) {
    _presentIds = List<String>.from(session.presentIds);
    _excusedIds = List<String>.from(session.excusedIds);
    _visitorIds = List<String>.from(session.visitorIds);
    _visitorRoles = Map<String, String>.from(session.visitorRoles);
    _dignitaryIds = List<String>.from(session.dignitaryIds);
    _dignitaryRoles = Map<String, String>.from(session.dignitaryRoles);
    _agapeIds = List<String>.from(session.agapeIds);
    _visitorAgapeIds = List<String>.from(session.visitorAgapeIds);
    _dignitaryAgapeIds = List<String>.from(session.dignitaryAgapeIds);
    _initialized = true;
  }

  void _togglePresent(String memberId) {
    setState(() {
      if (_presentIds.contains(memberId)) {
        _presentIds.remove(memberId);
      } else {
        _presentIds.add(memberId);
      }
      _excusedIds.remove(memberId);
      if (!_presentIds.contains(memberId)) _agapeIds.remove(memberId);
    });
  }

  void _toggleExcused(String memberId) {
    setState(() {
      if (_excusedIds.contains(memberId)) {
        _excusedIds.remove(memberId);
      } else {
        _excusedIds.add(memberId);
      }
      _presentIds.remove(memberId);
      _agapeIds.remove(memberId);
    });
  }

  void _toggleAgape(String memberId) {
    setState(() {
      if (_agapeIds.contains(memberId)) {
        _agapeIds.remove(memberId);
      } else {
        _agapeIds.add(memberId);
      }
    });
  }

  void _toggleVisitor(String visitorId) {
    setState(() {
      if (_visitorIds.contains(visitorId)) {
        _visitorIds.remove(visitorId);
        _visitorRoles.remove(visitorId);
        _visitorAgapeIds.remove(visitorId);
      } else {
        _visitorIds.add(visitorId);
      }
    });
  }

  void _toggleVisitorAgape(String visitorId) {
    setState(() {
      if (_visitorAgapeIds.contains(visitorId)) {
        _visitorAgapeIds.remove(visitorId);
      } else {
        _visitorAgapeIds.add(visitorId);
      }
    });
  }

  void _updateVisitorRole(String visitorId, String? role) {
    setState(() {
      if (role == null || role.isEmpty) {
        _visitorRoles.remove(visitorId);
      } else {
        _visitorRoles[visitorId] = role;
      }
    });
  }

  void _toggleDignitary(String dignitaryId) {
    setState(() {
      if (_dignitaryIds.contains(dignitaryId)) {
        _dignitaryIds.remove(dignitaryId);
        _dignitaryRoles.remove(dignitaryId);
        _dignitaryAgapeIds.remove(dignitaryId);
      } else {
        _dignitaryIds.add(dignitaryId);
      }
    });
  }

  void _toggleDignitaryAgape(String dignitaryId) {
    setState(() {
      if (_dignitaryAgapeIds.contains(dignitaryId)) {
        _dignitaryAgapeIds.remove(dignitaryId);
      } else {
        _dignitaryAgapeIds.add(dignitaryId);
      }
    });
  }

  void _updateDignitaryRole(String dignitaryId, String? role) {
    setState(() {
      if (role == null || role.isEmpty) {
        _dignitaryRoles.remove(dignitaryId);
      } else {
        _dignitaryRoles[dignitaryId] = role;
      }
    });
  }

  Future<void> _save(Session session) async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final map = Map<String, dynamic>.from(session.toMap());
    map['presentIds'] = _presentIds;
    map['excusedIds'] = _excusedIds;
    map['visitorIds'] = _visitorIds;
    map['visitorRoles'] = _visitorRoles;
    map['dignitaryIds'] = _dignitaryIds;
    map['dignitaryRoles'] = _dignitaryRoles;
    map['agapeIds'] = _agapeIds;
    map['visitorAgapeIds'] = _visitorAgapeIds;
    map['dignitaryAgapeIds'] = _dignitaryAgapeIds;
    try {
      await state.updateSession(Session.fromMap(session.id, map));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Présences enregistrées.'),
            backgroundColor: BrColors.teal,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur enregistrement : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = state.sessions.firstWhere(
      (s) => s.id == widget.sessionId,
      orElse: () => Session(id: widget.sessionId),
    );
    if (!_initialized) _initFrom(session);
    final canEdit = canEditSessions(state.currentUser);
    final isSuspended = session.isSuspended;
    final allowEdit = canEdit && !isSuspended;

    // Un membre ne peut assister qu'aux travaux de son grade ou en dessous.
    // Les membres déjà pointés restent affichés pour ne rien masquer.
    final sessionRank = Session.degreeRank(session.degreeLabel);
    final eligibleMembers = state.members
        .where((m) =>
            Session.degreeRank(m.grade) >= sessionRank ||
            _presentIds.contains(m.id) ||
            _excusedIds.contains(m.id))
        .toList();

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
              onPressed: _saving ? null : () => _save(session),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 28),
        children: [
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Lecture seule : seuls le V∴M∴, le Secrétaire et les administrateurs peuvent modifier les présences.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          if (isSuspended)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Tenue suspendue : les présences ne sont plus modifiables.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          const _SectionTitle('MEMBRES — PRÉSENTS / EXCUSÉS / AGAPES'),
          if (eligibleMembers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun membre.',
                  style: TextStyle(color: BrColors.muted)),
            ),
          for (final m in eligibleMembers)
            _MemberTile(
              name: m.fullName,
              role: m.function.isNotEmpty ? m.function : 'Membre',
              isPresent: _presentIds.contains(m.id),
              isExcused: _excusedIds.contains(m.id),
              isAgape: _agapeIds.contains(m.id),
              onPresent: allowEdit ? () => _togglePresent(m.id) : null,
              onExcused: allowEdit ? () => _toggleExcused(m.id) : null,
              onAgape: allowEdit ? () => _toggleAgape(m.id) : null,
            ),
          const SizedBox(height: 16),
          const _SectionTitle('VISITEURS — PRÉSENTS'),
          if (state.visitors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun visiteur.',
                  style: TextStyle(color: BrColors.muted)),
            )
          else ...[
            DirectoryFilterBar(
              controller: _visitorSearch,
              mode: _visitorMode,
              onModeChanged: (m) => setState(() => _visitorMode = m),
            ),
            const SizedBox(height: 12),
            ..._visitorSections(state.visitors, allowEdit),
          ],
          const SizedBox(height: 16),
          const _SectionTitle('DIGNITAIRES — PRÉSENTS'),
          if (state.dignitaries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun dignitaire.',
                  style: TextStyle(color: BrColors.muted)),
            )
          else ...[
            DirectoryFilterBar(
              controller: _dignitarySearch,
              mode: _dignitaryMode,
              onModeChanged: (m) => setState(() => _dignitaryMode = m),
            ),
            const SizedBox(height: 12),
            ..._dignitarySections(state.dignitaries, allowEdit),
          ],
        ],
      ),
    );
  }

  List<Widget> _visitorSections(List<Visitor> visitors, bool allowEdit) {
    final filtered =
        visitors
            .where(
              (v) => directoryMatches(_visitorSearch.text, [
                v.firstName,
                v.lastName,
                v.lodge,
                v.obedience,
              ]),
            )
            .toList()
          ..sort((a, b) => directoryCompare(a.lastName, b.lastName));
    if (filtered.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aucun résultat.', style: TextStyle(color: BrColors.muted)),
        ),
      ];
    }
    if (_visitorMode == DirectoryGroupMode.all) {
      return [for (final v in filtered) _visitorTile(v, allowEdit)];
    }
    final groups = groupDirectory(
      filtered,
      (v) => _visitorMode == DirectoryGroupMode.byLodge ? v.lodge : v.obedience,
    );
    return [
      for (final g in groups)
        DirectoryGroupSection(
          title: g.key,
          count: g.value.length,
          initiallyExpanded: groups.length == 1,
          children: [for (final v in g.value) _visitorTile(v, allowEdit)],
        ),
    ];
  }

  Widget _visitorTile(Visitor v, bool allowEdit) {
    return _VisitorTile(
      name: v.fullName,
      subtitle: [v.lodge, v.orient].where((e) => e.isNotEmpty).join(' — '),
      isPresent: _visitorIds.contains(v.id),
      isAgape: _visitorAgapeIds.contains(v.id),
      role: _visitorRoles[v.id] ?? '',
      onToggle: allowEdit ? () => _toggleVisitor(v.id) : null,
      onAgape: allowEdit ? () => _toggleVisitorAgape(v.id) : null,
      onRoleChanged: allowEdit ? (r) => _updateVisitorRole(v.id, r) : null,
    );
  }

  List<Widget> _dignitarySections(List<Dignitary> dignitaries, bool allowEdit) {
    final filtered =
        dignitaries
            .where(
              (d) => directoryMatches(_dignitarySearch.text, [
                d.firstName,
                d.lastName,
                d.lodge,
                d.obedience,
              ]),
            )
            .toList()
          ..sort((a, b) => directoryCompare(a.lastName, b.lastName));
    if (filtered.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aucun résultat.', style: TextStyle(color: BrColors.muted)),
        ),
      ];
    }
    if (_dignitaryMode == DirectoryGroupMode.all) {
      return [for (final d in filtered) _dignitaryTile(d, allowEdit)];
    }
    final groups = groupDirectory(
      filtered,
      (d) =>
          _dignitaryMode == DirectoryGroupMode.byLodge ? d.lodge : d.obedience,
    );
    return [
      for (final g in groups)
        DirectoryGroupSection(
          title: g.key,
          count: g.value.length,
          initiallyExpanded: groups.length == 1,
          children: [for (final d in g.value) _dignitaryTile(d, allowEdit)],
        ),
    ];
  }

  Widget _dignitaryTile(Dignitary d, bool allowEdit) {
    return _VisitorTile(
      name: d.fullName,
      subtitle: [
        if (d.title.isNotEmpty) d.title,
        d.lodge,
      ].where((e) => e.isNotEmpty).join(' — '),
      isPresent: _dignitaryIds.contains(d.id),
      isAgape: _dignitaryAgapeIds.contains(d.id),
      role: _dignitaryRoles[d.id] ?? '',
      onToggle: allowEdit ? () => _toggleDignitary(d.id) : null,
      onAgape: allowEdit ? () => _toggleDignitaryAgape(d.id) : null,
      onRoleChanged: allowEdit ? (r) => _updateDignitaryRole(d.id, r) : null,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: BrSectionTitle(text, icon: Icons.people_outline),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final bool isPresent;
  final bool isExcused;
  final bool isAgape;
  final VoidCallback? onPresent;
  final VoidCallback? onExcused;
  final VoidCallback? onAgape;
  const _MemberTile({
    required this.name,
    required this.role,
    required this.isPresent,
    required this.isExcused,
    required this.isAgape,
    required this.onPresent,
    required this.onExcused,
    required this.onAgape,
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
                  lastName:
                      name.split(' ').length > 1 ? name.split(' ').last : '',
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(role,
                          style: const TextStyle(
                              color: BrColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                _PresenceButton(
                  label: 'Présent',
                  selected: isPresent,
                  selectedColor: const Color(0xFF34D399),
                  onTap: onPresent,
                ),
                const SizedBox(width: 8),
                _PresenceButton(
                  label: 'Excusé',
                  selected: isExcused,
                  selectedColor: BrColors.gold,
                  onTap: onExcused,
                ),
              ],
            ),
            if (isPresent)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _PresenceButton(
                      label: 'Agapes',
                      selected: isAgape,
                      selectedColor: BrColors.teal,
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

class _VisitorTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isPresent;
  final bool isAgape;
  final String role;
  final VoidCallback? onToggle;
  final VoidCallback? onAgape;
  final ValueChanged<String?>? onRoleChanged;
  const _VisitorTile({
    required this.name,
    required this.subtitle,
    required this.isPresent,
    required this.isAgape,
    required this.role,
    required this.onToggle,
    required this.onAgape,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        accent: isPresent ? BrColors.teal : BrColors.muted,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BrAvatar(
                  firstName: name.split(' ').first,
                  lastName:
                      name.split(' ').length > 1 ? name.split(' ').last : '',
                  size: 40,
                  color: const Color(0xFF34D399),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                color: BrColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                _PresenceButton(
                  label: isPresent ? 'Présent' : 'Absent',
                  selected: isPresent,
                  selectedColor: BrColors.teal,
                  onTap: onToggle,
                ),
              ],
            ),
            if (isPresent) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role.isEmpty ? null : role,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Poste pendant la tenue',
                ),
                dropdownColor: BrColors.surface,
                style: const TextStyle(color: BrColors.text),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Aucun'),
                  ),
                  for (final option in _officeRoleOptions)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                ],
                onChanged: onRoleChanged,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _PresenceButton(
                    label: 'Agapes',
                    selected: isAgape,
                    selectedColor: BrColors.teal,
                    onTap: onAgape,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresenceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;
  const _PresenceButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
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
          color: selected
              ? selectedColor
              : BrColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor
                : BrColors.muted.withValues(alpha: 0.3),
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
