// Gestion des présences d'une tenue (porté depuis
// src/components/SessionPresenceScreen.tsx).
//
// Deux panneaux :
//  - MEMBRES : boutons « Présent » / « Excusé » mutuellement exclusifs
//    (gèrent session.presentIds / session.excusedIds).
//  - VISITEURS : toggle « Présent » / « Absent » (gère session.visitorIds) ;
//    lorsqu'il est présent, un menu déroulant « Poste pendant la tenue »
//    écrit dans session.visitorRoles[visitorId].
//
// L'enregistrement persiste les 4 champs (presentIds, excusedIds, visitorIds,
// visitorRoles) via AppState.updateSession, sans toucher au reste de la tenue.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/session.dart';
import '../state/app_state.dart';
import '../theme.dart';

const _visitorRoleOptions = [
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
  bool _initialized = false;
  bool _saving = false;

  void _initFrom(Session session) {
    _presentIds = List<String>.from(session.presentIds);
    _excusedIds = List<String>.from(session.excusedIds);
    _visitorIds = List<String>.from(session.visitorIds);
    _visitorRoles = Map<String, String>.from(session.visitorRoles);
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
    });
  }

  void _toggleVisitor(String visitorId) {
    setState(() {
      if (_visitorIds.contains(visitorId)) {
        _visitorIds.remove(visitorId);
        _visitorRoles.remove(visitorId);
      } else {
        _visitorIds.add(visitorId);
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

  Future<void> _save(Session session) async {
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final map = Map<String, dynamic>.from(session.toMap());
    map['presentIds'] = _presentIds;
    map['excusedIds'] = _excusedIds;
    map['visitorIds'] = _visitorIds;
    map['visitorRoles'] = _visitorRoles;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Présence'),
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
        padding: const EdgeInsets.all(12),
        children: [
          if (!canEdit)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Lecture seule : seuls le V∴M∴, le Secrétaire et les administrateurs peuvent modifier les présences.',
                style: TextStyle(color: BrColors.muted, fontSize: 12),
              ),
            ),
          const _SectionTitle('MEMBRES — PRÉSENTS / EXCUSÉS'),
          if (state.members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun membre.',
                  style: TextStyle(color: BrColors.muted)),
            ),
          for (final m in state.members)
            _MemberTile(
              name: m.fullName,
              role: m.function.isNotEmpty ? m.function : 'Membre',
              isPresent: _presentIds.contains(m.id),
              isExcused: _excusedIds.contains(m.id),
              onPresent: canEdit ? () => _togglePresent(m.id) : null,
              onExcused: canEdit ? () => _toggleExcused(m.id) : null,
            ),
          const SizedBox(height: 16),
          const _SectionTitle('VISITEURS — PRÉSENTS'),
          if (state.visitors.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun visiteur.',
                  style: TextStyle(color: BrColors.muted)),
            ),
          for (final v in state.visitors)
            _VisitorTile(
              name: v.fullName,
              subtitle: [v.lodge, v.orient]
                  .where((e) => e.isNotEmpty)
                  .join(' — '),
              isPresent: _visitorIds.contains(v.id),
              role: _visitorRoles[v.id] ?? '',
              onToggle: canEdit ? () => _toggleVisitor(v.id) : null,
              onRoleChanged:
                  canEdit ? (r) => _updateVisitorRole(v.id, r) : null,
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(
              color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final bool isPresent;
  final bool isExcused;
  final VoidCallback? onPresent;
  final VoidCallback? onExcused;
  const _MemberTile({
    required this.name,
    required this.role,
    required this.isPresent,
    required this.isExcused,
    required this.onPresent,
    required this.onExcused,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
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
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isPresent;
  final String role;
  final VoidCallback? onToggle;
  final ValueChanged<String?>? onRoleChanged;
  const _VisitorTile({
    required this.name,
    required this.subtitle,
    required this.isPresent,
    required this.role,
    required this.onToggle,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
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
                  for (final option in _visitorRoleOptions)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                ],
                onChanged: onRoleChanged,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
