// Répertoire du Souverain Sanctuaire — structure fournie par l'utilisateur :
// 7 catégories, chacune listant les documents/registres qu'elle couvrira.
// Purement informatif pour l'instant (pas de documents réels attachés) :
// une table des matières, pas encore un espace de stockage.
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/br_decor.dart';

class SstRepertoireCategory {
  final String title;
  final List<String> items;
  const SstRepertoireCategory(this.title, this.items);
}

const List<SstRepertoireCategory> kSstRepertoireCategories = [
  SstRepertoireCategory('Gouvernance & Instances', [
    'Convents (PV, ordres du jour, résolutions, élections)',
    'Composition du Souverain Sanctuaire (membres, mandats, dates de prise de fonction)',
    'Succession / élection du Grand Maître-Grand Hiérophante',
  ]),
  SstRepertoireCategory('Textes fondamentaux', [
    'Constitutions',
    'Règlements généraux',
    'Rituels (par degré/classe : Loges, Chapitres, Aréopages, Tribunaux, Consistoires)',
    'Landmarks / doctrine du Rite',
  ]),
  SstRepertoireCategory('Relations extérieures', [
    "Traités d'amitié (par obédience, avec dates et statut actif/rompu)",
    'Reconnaissances de régularité',
    'Correspondance internationale',
    'Participation à des fédérations/confédérations (Souverain Sanctuaire International, etc.)',
  ]),
  SstRepertoireCategory('Filiation & légitimité des ateliers', [
    'Patentes délivrées (par loge/chapitre/aréopage, avec numéro et date)',
    'Mises en sommeil / réveils',
    'Radiations',
  ]),
  SstRepertoireCategory('Hauts grades', [
    'Registre des détenteurs par degré',
    'Brevets/diplômes délivrés',
    'Calendrier des intronisations',
    "Jurys et conditions d'accès",
  ]),
  SstRepertoireCategory('Discipline & contentieux', [
    'Sanctions, suspensions, exclusions',
    'Arbitrages de conflits internes',
  ]),
  SstRepertoireCategory('Patrimoine', [
    'Trésor / comptabilité des hauts grades',
    'Archives historiques',
    'Sceaux, regalia, symboles',
  ]),
];

class GrandeLogeSstRepertoireScreen extends StatelessWidget {
  const GrandeLogeSstRepertoireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Répertoire du Souverain Sanctuaire')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final category in kSstRepertoireCategories)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BrMenuTile(
                title: category.title,
                subtitle: '${category.items.length} rubrique(s)',
                icon: Icons.folder_outlined,
                color: BrColors.gold,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _SstCategoryScreen(category: category),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SstCategoryScreen extends StatelessWidget {
  final SstRepertoireCategory category;
  const _SstCategoryScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in category.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BrCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.chevron_right,
                      color: BrColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: BrColors.text,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
