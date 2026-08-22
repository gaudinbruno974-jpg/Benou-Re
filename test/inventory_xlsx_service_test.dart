import 'package:benou_re/models/inventory_item.dart';
import 'package:benou_re/services/directory_xlsx_service.dart' show ImportAction;
import 'package:benou_re/services/inventory_xlsx_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('itemKey', () {
    test('insensible à la casse et aux accents', () {
      expect(itemKey('Objets rituels', 'Épée'), itemKey('objets rituels', 'epee'));
    });

    test('distingue deux articles de même nom dans des catégories différentes', () {
      expect(itemKey('Salle Humide', 'Coussin'), isNot(itemKey('Temple', 'Coussin')));
    });
  });

  final items = [
    const InventoryItem(
      id: 'i1',
      category: 'Objets rituels',
      name: 'Encensoir',
      quantity: '1',
      property: kInvPropLoge,
      note: "Sur l'Autel du Naos",
    ),
    const InventoryItem(
      id: 'i2',
      category: 'Mobilier',
      name: 'Colonne du Second Surveillant',
      quantity: '1',
      property: kInvPropFFSS,
      lentBy: 'Jean DUPONT',
    ),
  ];

  group('export puis import', () {
    test('un article déjà présent (même catégorie + nom) est reconnu comme doublon', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, items);
      expect(rows, hasLength(2));
      expect(rows[0].action, ImportAction.update);
      expect(rows[0].existing?.id, 'i1');
      expect(rows[1].action, ImportAction.update);
      expect(rows[1].existing?.id, 'i2');
    });

    test('un article absent de la base est proposé en création', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, const []);
      expect(rows.every((r) => r.action == ImportAction.create), isTrue);
      expect(rows.every((r) => r.existing == null), isTrue);
    });

    test('reprend fidèlement propriété, prêt et note', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, const []);
      final colonne = rows.firstWhere((r) => r.name == 'Colonne du Second Surveillant');
      expect(colonne.category, 'Mobilier');
      expect(colonne.property, kInvPropFFSS);
      expect(colonne.lentBy, 'Jean DUPONT');
      final encensoir = rows.firstWhere((r) => r.name == 'Encensoir');
      expect(encensoir.note, "Sur l'Autel du Naos");
    });

    test('resolve(create) construit un nouvel article avec un id fourni', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, const []);
      final row = rows.first;
      final created = row.resolve(() => 'new-id');
      expect(created?.id, 'new-id');
      expect(created?.name, row.name);
    });

    test('resolve(update) conserve l\'id existant', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, items);
      final row = rows.firstWhere((r) => r.name == 'Encensoir');
      final updated = row.resolve(() => 'unused');
      expect(updated?.id, 'i1');
    });

    test('resolve(skip) renvoie null', () {
      final bytes = buildInventoryWorkbook(items);
      final rows = parseInventorySheet(bytes, items);
      final row = rows.first..action = ImportAction.skip;
      expect(row.resolve(() => 'x'), isNull);
    });

    test('une ligne sans nom est ignorée', () {
      final template = buildInventoryTemplate();
      final rows = parseInventorySheet(template, const []);
      expect(rows, isEmpty);
    });
  });
}
