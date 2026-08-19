import 'package:flutter_test/flutter_test.dart';

import 'package:benou_re/widgets/directory_filter.dart';

void main() {
  group('directoryMatches', () {
    test('une requête vide retourne toujours vrai', () {
      expect(directoryMatches('', ['Dupont']), isTrue);
      expect(directoryMatches('   ', []), isTrue);
    });

    test('recherche insensible à la casse et aux accents', () {
      expect(directoryMatches('elise', ['Éliséman']), isTrue);
      expect(directoryMatches('ÉLISE', ['eliseman']), isTrue);
      expect(directoryMatches('gldb', ['GLDB']), isTrue);
    });

    test('correspond si au moins un champ contient la requête', () {
      expect(
        directoryMatches('reunion', ['Dupont', 'Jean', '', 'La Réunion']),
        isTrue,
      );
      expect(
        directoryMatches('maroc', ['Dupont', 'Jean', 'GLDB', 'La Réunion']),
        isFalse,
      );
    });
  });

  group('directoryCompare', () {
    test('trie les accents comme le reste de l\'alphabet', () {
      final names = ['Zoé', 'Émile', 'Amine'];
      names.sort(directoryCompare);
      expect(names, ['Amine', 'Émile', 'Zoé']);
    });

    test('ignore la casse', () {
      expect(directoryCompare('abc', 'ABD') < 0, isTrue);
    });
  });

  group('groupDirectory', () {
    test('regroupe par la valeur retournée, groupes triés', () {
      final items = ['a-GLNF', 'b-GLDB', 'c-GLDB'];
      final groups = groupDirectory(items, (s) => s.split('-')[1]);
      expect(groups.map((g) => g.key), ['GLDB', 'GLNF']);
      expect(groups.first.value, ['b-GLDB', 'c-GLDB']);
    });

    test('conserve l\'ordre reçu à l\'intérieur d\'un groupe', () {
      final items = ['b-X', 'a-X'];
      final groups = groupDirectory(items, (s) => s.split('-')[1]);
      expect(groups.single.value, ['b-X', 'a-X']);
    });

    test('les valeurs vides sont reléguées dans "Non renseigné", en dernier',
        () {
      final items = ['a-GLNF', 'b-', 'c-GLDB'];
      final groups = groupDirectory(items, (s) => s.split('-')[1]);
      expect(groups.map((g) => g.key), ['GLDB', 'GLNF', kDirectoryUngrouped]);
      expect(groups.last.value, ['b-']);
    });

    test('le tri des groupes gère les accents', () {
      final items = ['a-Émile', 'b-Amine', 'c-Zoé'];
      final groups = groupDirectory(items, (s) => s.split('-')[1]);
      expect(groups.map((g) => g.key), ['Amine', 'Émile', 'Zoé']);
    });
  });

  group('distinctSuggestions', () {
    test('déduplique, ignore les valeurs vides, trie', () {
      expect(
        distinctSuggestions(['GLDB', 'GLNF', 'GLDB', '', '  ', 'Émile']),
        ['Émile', 'GLDB', 'GLNF'],
      );
    });
  });
}
