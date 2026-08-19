// Recherche et regroupement partagés entre les répertoires Visiteurs et
// Dignitaires : visitors_screen.dart, dignitaries_screen.dart, les panneaux
// Visiteurs/Dignitaires de session_presence_screen.dart, et la carte
// « Invités par e-mail » de session_invitations_screen.dart.
//
// La recherche est insensible à la casse et aux accents (voir `foldLabel`,
// déjà utilisé ailleurs dans l'app) ; le regroupement se fait par Loge
// d'origine ou par Obédience, deux champs texte déjà présents sur Visitor et
// Dignitary — aucun changement de modèle de données.
import 'package:flutter/material.dart';

import '../models/member.dart' show foldLabel;
import '../theme.dart';
import 'br_decor.dart';

enum DirectoryGroupMode { all, byLodge, byObedience }

const String kDirectoryUngrouped = 'Non renseigné';

/// Compare deux libellés en ignorant casse et accents, pour un tri
/// alphabétique français correct (ex. « Émile » avant « Zoé »).
int directoryCompare(String a, String b) =>
    foldLabel(a).compareTo(foldLabel(b));

/// Vrai si l'un des [fields] contient [query] — recherche insensible à la
/// casse et aux accents. Une requête vide (ou blanche) retourne toujours vrai.
bool directoryMatches(String query, Iterable<String> fields) {
  final needle = foldLabel(query);
  if (needle.isEmpty) return true;
  return fields.any((f) => foldLabel(f).contains(needle));
}

/// Regroupe [items] (déjà filtrés/triés par l'appelant) par la valeur que
/// [groupOf] leur associe (Loge ou Obédience), en conservant leur ordre à
/// l'intérieur de chaque groupe. Groupes triés alphabétiquement ; les fiches
/// dont le champ est vide sont reléguées dans [kDirectoryUngrouped], toujours
/// en dernier.
List<MapEntry<String, List<T>>> groupDirectory<T>(
  List<T> items,
  String Function(T) groupOf,
) {
  final groups = <String, List<T>>{};
  for (final item in items) {
    final raw = groupOf(item).trim();
    final key = raw.isEmpty ? kDirectoryUngrouped : raw;
    groups.putIfAbsent(key, () => []).add(item);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a == kDirectoryUngrouped) return b == kDirectoryUngrouped ? 0 : 1;
      if (b == kDirectoryUngrouped) return -1;
      return directoryCompare(a, b);
    });
  return [for (final k in keys) MapEntry(k, groups[k]!)];
}

/// Valeurs distinctes non vides de [values], triées alphabétiquement —
/// utilisé pour les suggestions d'autocomplétion Loge/Obédience.
List<String> distinctSuggestions(Iterable<String> values) {
  final set = values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet();
  final list = set.toList()..sort(directoryCompare);
  return list;
}

/// Barre de recherche + sélecteur Tous / Par Loge / Par Obédience.
class DirectoryFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final DirectoryGroupMode mode;
  final ValueChanged<DirectoryGroupMode> onModeChanged;
  final String hintText;
  const DirectoryFilterBar({
    super.key,
    required this.controller,
    required this.mode,
    required this.onModeChanged,
    this.hintText = 'Rechercher un nom, une Loge, une Obédience…',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: BrColors.text),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search, color: BrColors.muted),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: BrColors.muted,
                      size: 18,
                    ),
                    onPressed: controller.clear,
                  ),
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<DirectoryGroupMode>(
          segments: const [
            ButtonSegment(value: DirectoryGroupMode.all, label: Text('Tous')),
            ButtonSegment(
              value: DirectoryGroupMode.byLodge,
              label: Text('Par Loge'),
            ),
            ButtonSegment(
              value: DirectoryGroupMode.byObedience,
              label: Text('Par Obédience'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
          style: SegmentedButton.styleFrom(
            backgroundColor: BrColors.backgroundDark.withValues(alpha: 0.5),
            foregroundColor: BrColors.muted,
            selectedBackgroundColor: BrColors.teal,
            selectedForegroundColor: Colors.white,
            side: BorderSide(color: BrColors.gold.withValues(alpha: 0.3)),
          ),
        ),
      ],
    );
  }
}

/// Section repliable d'un groupe (Loge ou Obédience), avec le nombre de
/// fiches à côté du nom du groupe.
class DirectoryGroupSection extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;
  final bool initiallyExpanded;
  const DirectoryGroupSection({
    super.key,
    required this.title,
    required this.count,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BrCard(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 10),
            leading: const Icon(Icons.folder_outlined, color: BrColors.gold),
            title: Text(
              '$title ($count)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Champ texte avec autocomplétion sur des suggestions déjà connues (Loge
/// d'origine, Obédience…) : l'utilisateur reste libre de saisir une valeur
/// absente des suggestions (même mécanique que la catégorie d'un article
/// dans l'écran Matériel, voir inventory_screen.dart).
class DirectoryAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final List<String> suggestions;
  const DirectoryAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (v) {
          if (v.text.trim().isEmpty) return suggestions;
          final needle = foldLabel(v.text);
          return suggestions.where((s) => foldLabel(s).contains(needle));
        },
        onSelected: (v) => controller.text = v,
        fieldViewBuilder: (ctx, fieldController, focusNode, onSubmit) {
          fieldController.text = controller.text;
          fieldController.addListener(
            () => controller.text = fieldController.text,
          );
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            style: const TextStyle(color: BrColors.text),
            decoration: InputDecoration(labelText: label),
          );
        },
      ),
    );
  }
}
