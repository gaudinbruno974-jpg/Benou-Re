// Parvis / tableau de bord (porté depuis src/components/ParvisScreen.tsx).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/lodge_config.dart';
import '../models/member.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/br_decor.dart';
import 'dignitaries_screen.dart';
import 'activity_report_screen.dart';
import 'external_sessions_screen.dart';
import 'inventory_screen.dart';
import 'members_screen.dart';
import 'sessions_screen.dart';
import 'statistics_screen.dart';
import 'visitors_screen.dart';
import 'treasury_screen.dart';
import 'library_screen.dart';
import 'agape_payment_sessions_screen.dart';
import 'support_request_screen.dart';
import 'drive_access_sync_screen.dart';

/// Cartes du Parvis, dans leur ordre d'affichage — réutilisé par
/// support_request_screen.dart pour le menu « Votre demande concerne ».
const List<String> kParvisCardTitles = [
  'Tenues',
  'Paiement des Agapes',
  'Tenues extérieures',
  'Membres',
  'Visiteurs',
  'Dignitaires',
  "Morceaux d'architecture",
  'Instructions',
  'Rituels',
  'Matériel',
  'Trésorerie',
  'Statistiques',
  'Rapport pour la Grande Loge',
];

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool visible;
  final Widget Function() build;
  const _MenuItem(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.visible,
    this.build,
  );
}

class ParvisScreen extends StatelessWidget {
  const ParvisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser!;
    final lodge = LodgeConfig.current;
    final isTreasury = canEditTreasury(user) || canEditSessions(user);
    final isVisitors = canEditSessions(user);
    final isVM = isVenerableMaitre(user);

    final items = <_MenuItem>[
      _MenuItem(
        'Tenues',
        '${state.sessions.length} tenue(s)',
        Icons.calendar_today,
        BrColors.teal,
        true,
        () => const SessionsScreen(),
      ),
      _MenuItem(
        'Paiement des Agapes',
        'Médailles & signatures',
        Icons.restaurant_outlined,
        BrColors.menuTresorerie,
        isTreasury,
        () => const AgapePaymentSessionsScreen(),
      ),
      _MenuItem(
        'Tenues extérieures',
        '${state.externalSessions.where((s) => !s.isPast).length} à venir',
        Icons.outbound_outlined,
        BrColors.gold,
        isVisitors,
        () => const ExternalSessionsScreen(),
      ),
      _MenuItem(
        'Membres',
        '${state.members.length} membre(s)',
        Icons.people_outline,
        BrColors.gold,
        true,
        () => const MembersScreen(),
      ),
      _MenuItem(
        'Visiteurs',
        '${state.visitors.length} visiteur(s)',
        Icons.shield_outlined,
        BrColors.menuVisiteurs,
        isVisitors,
        () => const VisitorsScreen(),
      ),
      _MenuItem(
        'Dignitaires',
        '${state.dignitaries.length} enregistré(s)',
        Icons.workspace_premium_outlined,
        BrColors.violet,
        isVisitors,
        () => const DignitariesScreen(),
      ),
      _MenuItem(
        "Morceaux d'architecture",
        'Planches et travaux',
        Icons.history_edu,
        BrColors.menuArchitecture,
        true,
        () => const LibraryScreen(type: 'Architecture'),
      ),
      _MenuItem(
        'Instructions',
        'Cahiers de formation',
        Icons.school_outlined,
        BrColors.menuInstruction,
        true,
        () => const LibraryScreen(type: 'Instructions'),
      ),
      _MenuItem(
        'Rituels',
        'Textes sacrés',
        Icons.menu_book_outlined,
        BrColors.menuRituels,
        true,
        () => const LibraryScreen(type: 'Rituels'),
      ),
      _MenuItem(
        'Matériel',
        '${state.inventoryItems.length} article(s) référencé(s)',
        Icons.inventory_2_outlined,
        BrColors.menuInventaire,
        true,
        () => const InventoryScreen(),
      ),
      _MenuItem(
        'Trésorerie',
        'Bilans & Cotisations',
        Icons.work_outline,
        BrColors.menuTresorerie,
        isTreasury,
        () => const TreasuryScreen(),
      ),
      _MenuItem(
        'Statistiques',
        'Assiduité & fréquentation',
        Icons.query_stats_outlined,
        BrColors.violet,
        isVM,
        () => const StatisticsScreen(),
      ),
      _MenuItem(
        'Rapport pour la Grande Loge',
        'Rapport d\'activité PDF',
        Icons.summarize_outlined,
        BrColors.menuArchitecture,
        isVM,
        () => const ActivityReportScreen(),
      ),
      _MenuItem(
        'Suggestions / Dysfonctionnements',
        'Signaler un bug ou une idée',
        Icons.support_agent_outlined,
        BrColors.gold,
        canEditSessions(user),
        () => const SupportRequestScreen(),
      ),
      _MenuItem(
        'Accès Drive',
        'Synchroniser les autorisations',
        Icons.sync,
        BrColors.violet,
        isVM,
        () => const DriveAccessSyncScreen(),
      ),
    ];
    final visibleItems = items.where((i) => i.visible).toList();

    final activeMembers = state.members
        .where((m) => m.status == 'Actif')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BrColors.backgroundDark.withValues(alpha: 0.8),
                border: Border.all(
                  color: BrColors.gold.withValues(alpha: 0.45),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: BrColors.goldBright,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'R∴L∴ ${lodge.name}',
                  style: const TextStyle(fontSize: 16, letterSpacing: 1),
                ),
                Text(
                  'Orient de ${lodge.orient}',
                  style: const TextStyle(fontSize: 11, color: BrColors.muted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Quitter le Temple',
            icon: const Icon(Icons.logout, color: BrColors.menuTresorerie),
            onPressed: () => state.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BrCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrAvatar(
                      firstName: user.firstName,
                      lastName: user.lastName,
                      size: 52,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salutations Fraternelles, mon T. C. F. ${user.firstName}',
                            style: const TextStyle(
                              color: BrColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Bienvenue sur le Parvis numérique de la Loge. Retrouvez ici les fiches de vos Frères, le calendrier des travaux, les planches d'architecture et les outils de trésorerie.",
                            style: TextStyle(
                              color: BrColors.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatCard(
                  label: 'Membres actifs',
                  value: '$activeMembers',
                  icon: Icons.people,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Tenues',
                  value: '${state.sessions.length}',
                  icon: Icons.calendar_month,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Visiteurs',
                  value: '${state.visitors.length}',
                  icon: Icons.shield,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Dignitaires',
                  value: '${state.dignitaries.length}',
                  icon: Icons.workspace_premium,
                ),
              ],
            ),
            const SizedBox(height: 28),
            const BrSectionTitle(
              'VOTRE ESPACE DE TRAVAIL',
              icon: Icons.workspaces_outline,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 4.2,
                  children: [
                    for (final item in visibleItems)
                      _MenuCard(
                        item: item,
                        onTap: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => item.build())),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'R∴L∴ ${lodge.name} • RAPMM • v1.0.0',
                style: TextStyle(
                  color: BrColors.muted.withValues(alpha: 0.7),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
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
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BrCard(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Container(
                height: 38,
                width: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BrColors.gold.withValues(alpha: 0.14),
                  border: Border.all(
                    color: BrColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, color: BrColors.goldBright, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  color: BrColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrColors.muted,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
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
    return BrCard(
      onTap: onTap,
      accent: item.color,
      padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(BrColors.radiusS),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color.withValues(alpha: 0.28),
                      item.color.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: item.color.withValues(alpha: 0.45)),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrColors.text,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: BrColors.gold.withValues(alpha: 0.8),
                size: 15,
              ),
            ],
          ),
    );
  }
}
