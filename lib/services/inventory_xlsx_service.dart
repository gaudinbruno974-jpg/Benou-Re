// Export / import de l'inventaire du matériel en un classeur .xlsx à une
// feuille — même principe que directory_xlsx_service.dart (Membres/
// Visiteurs/Dignitaires) : détection de doublon à l'import, choix ligne par
// ligne entre création, mise à jour, ou ignorer. Voir xlsx_codec.dart pour la
// lecture/écriture du fichier lui-même.
import '../models/inventory_item.dart';
import '../models/member.dart' show foldLabel;
import 'directory_xlsx_service.dart' show ImportAction;
import 'xlsx_codec.dart';

const String kSheetInventory = 'Matériel';

const List<String> kInventoryHeaders = [
  'Catégorie',
  'Nom',
  'Quantité',
  'Propriété',
  'Prêté par',
  'Note',
];

String _cell(List<String> row, int i) => i < row.length ? row[i].trim() : '';

/// Clé de rapprochement pour la détection de doublon : catégorie + nom,
/// insensible à la casse et aux accents (même convention que les
/// répertoires, voir directory_xlsx_service.dart:nameKey) — un même nom
/// d'article peut exister dans deux catégories différentes.
String itemKey(String category, String name) => foldLabel('$category|$name');

// ─── Export ───────────────────────────────────────────────────────────

List<List<String>> _inventoryRows(List<InventoryItem> items) => [
  kInventoryHeaders,
  for (final i in items)
    [
      i.category,
      i.name,
      i.quantity,
      i.property,
      i.lentBy ?? '',
      i.note ?? '',
    ],
];

/// Classeur complet (données réelles) de l'inventaire.
List<int> buildInventoryWorkbook(List<InventoryItem> items) {
  return buildXlsx({kSheetInventory: _inventoryRows(items)});
}

/// Classeur modèle : uniquement les en-têtes, aucune ligne de donnée.
List<int> buildInventoryTemplate() {
  return buildXlsx({
    kSheetInventory: [kInventoryHeaders],
  });
}

// ─── Import ───────────────────────────────────────────────────────────

class InventoryImportRow {
  final String category;
  final String name;
  final String quantity;
  final String property;
  final String lentBy;
  final String note;
  final InventoryItem? existing;
  ImportAction action;

  InventoryImportRow({
    required this.category,
    required this.name,
    required this.quantity,
    required this.property,
    required this.lentBy,
    required this.note,
    required this.existing,
    required this.action,
  });

  /// Fiche telle qu'elle sera écrite, selon [action] — `null` si `skip`.
  InventoryItem? resolve(String Function() newId) {
    switch (action) {
      case ImportAction.skip:
        return null;
      case ImportAction.create:
        return InventoryItem(
          id: newId(),
          category: category,
          name: name,
          quantity: quantity,
          property: property.isEmpty ? kInvPropLoge : property,
          lentBy: lentBy.isEmpty ? null : lentBy,
          note: note.isEmpty ? null : note,
        );
      case ImportAction.update:
        final base = existing;
        if (base == null) return null;
        return InventoryItem(
          id: base.id,
          category: category,
          name: name,
          quantity: quantity,
          property: property.isEmpty ? kInvPropLoge : property,
          lentBy: lentBy.isEmpty ? null : lentBy,
          note: note.isEmpty ? null : note,
        );
    }
  }
}

/// Lignes de la feuille « Matériel » d'un classeur importé, associées à un
/// article existant (catégorie + nom) si elle en trouve un, avec une action
/// par défaut (mise à jour pour un doublon détecté, création sinon) —
/// modifiable ensuite ligne par ligne dans l'écran de prévisualisation. Les
/// lignes sans nom sont ignorées (lignes vides en fin de tableau).
List<InventoryImportRow> parseInventorySheet(
  List<int> bytes,
  List<InventoryItem> existingItems,
) {
  final rows =
      readXlsx(bytes, [kSheetInventory])[kSheetInventory] ?? const [];
  final byKey = {
    for (final i in existingItems) itemKey(i.category, i.name): i,
  };
  final result = <InventoryImportRow>[];
  for (final row in rows.skip(1)) {
    final name = _cell(row, 1);
    if (name.isEmpty) continue;
    final category = _cell(row, 0);
    final existing = byKey[itemKey(category, name)];
    result.add(
      InventoryImportRow(
        category: category,
        name: name,
        quantity: _cell(row, 2),
        property: _cell(row, 3),
        lentBy: _cell(row, 4),
        note: _cell(row, 5),
        existing: existing,
        action: existing == null ? ImportAction.create : ImportAction.update,
      ),
    );
  }
  return result;
}
