import 'package:benou_re/services/xlsx_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un classeur écrit se relit à l\'identique (aller-retour)', () {
    final sheets = {
      'Membres': [
        ['Civilité', 'Prénom', 'Nom'],
        ['Frère', 'Bruno', 'GAUDIN'],
        ['Sœur', 'Murielle', 'MARTIN-FANOU'],
      ],
      'Visiteurs': [
        ['Prénom', 'Nom'],
        ['Jean', 'Dupont'],
      ],
      'Dignitaires': [
        ['Prénom', 'Nom'],
      ],
    };

    final bytes = buildXlsx(sheets);
    final read = readXlsx(bytes, ['Membres', 'Visiteurs', 'Dignitaires']);

    expect(read['Membres'], sheets['Membres']);
    expect(read['Visiteurs'], sheets['Visiteurs']);
    expect(read['Dignitaires'], sheets['Dignitaires']);
  });

  test('échappe correctement les caractères spéciaux XML', () {
    final sheets = {
      'Test': [
        ['Nom & Prénom', '<balise>', 'guillemets "et" apostrophes \''],
      ],
    };
    final bytes = buildXlsx(sheets);
    final read = readXlsx(bytes, ['Test']);
    expect(read['Test'], sheets['Test']);
  });

  test('conserve les accents et les espaces significatifs', () {
    final sheets = {
      'Test': [
        ['  espaces  ', 'Éléonore', 'Frédéric'],
      ],
    };
    final bytes = buildXlsx(sheets);
    final read = readXlsx(bytes, ['Test']);
    expect(read['Test'], sheets['Test']);
  });

  test('une feuille demandée mais absente du fichier est simplement omise', () {
    final bytes = buildXlsx({
      'Membres': [
        ['Nom'],
      ],
    });
    final read = readXlsx(bytes, ['Membres', 'Inconnue']);
    expect(read.containsKey('Membres'), isTrue);
    expect(read.containsKey('Inconnue'), isFalse);
  });

  test('la correspondance des noms de feuille ignore la casse', () {
    final bytes = buildXlsx({
      'Membres': [
        ['Nom'],
      ],
    });
    final read = readXlsx(bytes, ['membres']);
    expect(read['membres'], [
      ['Nom'],
    ]);
  });

  test(
    'chaque ligne se relit avec sa propre largeur (pas complétée sur la '
    'largeur des autres lignes) : à la lecture d\'accéder aux colonnes par '
    'index de façon sûre, y compris hors bornes',
    () {
      final bytes = buildXlsx({
        'Test': [
          ['a', 'b', 'c'],
          ['x'],
        ],
      });
      final read = readXlsx(bytes, ['Test']);
      expect(read['Test'], [
        ['a', 'b', 'c'],
        ['x'],
      ]);
    },
  );
}
