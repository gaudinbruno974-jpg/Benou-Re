// Présences d'une tenue d'un corps de Hauts Grades — même principe que
// session_presence_screen.dart (loges bleues) : membres présents/excusés,
// visiteurs et dignitaires présents, tous avec une case Agapes. Pas de
// « poste pendant la tenue » pour les visiteurs/dignitaires (les offices
// d'une loge bleue — Surveillant, Orateur... — ne s'appliquent pas à un
// Collège de Perfection sans référence pour les remplacer).
import 'package:flutter/material.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/hg_session.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import '../services/hg_body_service.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';

class GrandeLogeHgPresenceScreen extends StatefulWidget {
  final HgBody body;
  final HgSession session;
  const GrandeLogeHgPresenceScreen({
    super.key,
    required this.body,
    required this.session,
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

  void _toggleDignitaryAgape(String id) {
    setState(() {
      if (_dignitaryAgapeIds.contains(id)) {
        _dignitaryAgapeIds.remove(id);
      } else {
        _dignitaryAgapeIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = widget.session.copyWith(
        presentIds: _presentIds,
        excusedIds: _excusedIds,
        agapeIds: _agapeIds,
        visitorIds: _visitorIds,
        visitorAgapeIds: _visitorAgapeIds,
        dignitaryIds: _dignitaryIds,
        dignitaryAgapeIds: _dignitaryAgapeIds,
      );
      await HgBodyService.instance.saveSession(widget.body, updated);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Présence'),
        actions: [
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
          const BrSectionTitle(
            'MEMBRES — PRÉSENTS / EXCUSÉS / AGAPES',
            icon: Icons.people_outline,
          ),
          StreamBuilder<List<Member>>(
            stream: HgBodyService.instance.membersStream(widget.body),
            builder: (context, snap) {
              final members = snap.data ?? const [];
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
                      onPresent: () => _togglePresent(m.id),
                      onExcused: () => _toggleExcused(m.id),
                      onAgape: () => _toggleAgape(m.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const BrSectionTitle(
            'VISITEURS — PRÉSENTS / AGAPES',
            icon: Icons.shield_outlined,
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
                      onPresent: () => _toggleVisitor(v.id),
                      onExcused: null,
                      onAgape: () => _toggleVisitorAgape(v.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const BrSectionTitle(
            'DIGNITAIRES — PRÉSENTS / AGAPES',
            icon: Icons.workspace_premium_outlined,
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
                      onPresent: () => _toggleDignitary(d.id),
                      onExcused: null,
                      onAgape: () => _toggleDignitaryAgape(d.id),
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
  final VoidCallback? onPresent;
  final VoidCallback? onExcused;
  final VoidCallback? onAgape;
  const _PresenceTile({
    required this.name,
    required this.subtitle,
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
