// Parvis / tableau de bord (porté depuis src/components/ParvisScreen.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'members_screen.dart';
import 'sessions_screen.dart';
import 'visitors_screen.dart';
import 'treasury_screen.dart';
import 'library_screen.dart';

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool visible;
  final Widget Function() build;
  const _MenuItem(this.title, this.subtitle, this.icon, this.color,
      this.visible, this.build);
}

class ParvisScreen extends StatelessWidget {
  const ParvisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser!;
    final fn = user.function.trim();
    final isAdmin = user.isAdmin;
    final isTreasury = isAdmin ||
        fn.contains('Trésorier') ||
        fn.contains('Vénérable Maître') ||
        fn.contains('Secrétaire');
    final isVisitors = isAdmin ||
        fn.contains('Vénérable Maître') ||
        fn.contains('Secrétaire');

    final items = <_MenuItem>[
      _MenuItem('Membres', 'Tableau des colonnes', Icons.people_outline,
          BrColors.gold, true, () => const MembersScreen()),
      _MenuItem('Tenues', 'Calendrier des travaux', Icons.calendar_today,
          BrColors.teal, true, () => const SessionsScreen()),
      _MenuItem('Visiteurs', 'Répertoire des visiteurs', Icons.shield_outlined,
          const Color(0xFF34D399), isVisitors, () => const VisitorsScreen()),
      _MenuItem(
          "Morceaux d'architecture",
          'Planches et travaux',
          Icons.history_edu,
          const Color(0xFF38BDF8),
          true,
          () => const LibraryScreen(type: 'Architecture')),
      _MenuItem('Instructions', 'Cahiers de formation', Icons.school_outlined,
          const Color(0xFF818CF8), true,
          () => const LibraryScreen(type: 'Instructions')),
      _MenuItem('Rituels', 'Textes sacrés', Icons.menu_book_outlined,
          const Color(0xFFA78BFA), true,
          () => const LibraryScreen(type: 'Rituels')),
      _MenuItem('Trésorerie', 'Bilans & Cotisations', Icons.work_outline,
          const Color(0xFFFB7185), isTreasury, () => const TreasuryScreen()),
    ];
    final visibleItems = items.where((i) => i.visible).toList();

    final activeMembers =
        state.members.where((m) => m.status == 'Actif').length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: BrColors.background,
              child: Icon(Icons.auto_awesome, color: BrColors.gold, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('R. L. Bénou Ré',
                    style: TextStyle(fontSize: 16, letterSpacing: 1)),
                Text('Orient de Saint-Pierre',
                    style: TextStyle(fontSize: 11, color: BrColors.muted)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quitter le Temple',
            icon: const Icon(Icons.logout, color: Color(0xFFFB7185)),
            onPressed: () => state.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salutations Fraternelles, mon T. C. F. ${user.firstName}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Bienvenue sur le Parvis numérique de la Loge. Retrouvez ici les fiches de vos Frères, le calendrier des travaux, les planches d'architecture et les outils de trésorerie.",
                      style: TextStyle(color: BrColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatCard(
                    label: 'Membres actifs',
                    value: '$activeMembers',
                    icon: Icons.people),
                const SizedBox(width: 12),
                _StatCard(
                    label: 'Tenues',
                    value: '${state.sessions.length}',
                    icon: Icons.calendar_month),
                const SizedBox(width: 12),
                _StatCard(
                    label: 'Visiteurs',
                    value: '${state.visitors.length}',
                    icon: Icons.shield),
              ],
            ),
            const SizedBox(height: 24),
            const Text('VOTRE ESPACE DE TRAVAIL',
                style: TextStyle(
                    color: BrColors.gold, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final cols = constraints.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 4.5,
                children: [
                  for (final item in visibleItems)
                    _MenuCard(
                      item: item,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => item.build()),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 24),
            const Center(
              child: Text('RL Bénou Ré • RAPMM • v1.0.0',
                  style: TextStyle(color: BrColors.muted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: BrColors.gold, size: 22),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BrColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onTap;
  const _MenuCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: item.color.withValues(alpha: 0.1),
                  border:
                      Border.all(color: item.color.withValues(alpha: 0.3)),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: BrColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  color: BrColors.gold, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
