import 'package:benou_re/config/lodge_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les titres dérivés reprennent mot pour mot ceux des documents', () {
    const lodge = LodgeConfig.benouRe;
    // Ces deux formes figurent telles quelles sur la convocation, la feuille
    // de présence et la planche tracée : les dériver du nom ne doit rien
    // changer au rendu des documents officiels.
    expect(lodge.shortTitle, 'R∴ L∴ Bénou Ré N°5');
    expect(lodge.formalTitleUpper, 'Respectable Loge BENOU RE N°5');
    expect(lodge.nameUpperAscii, 'BENOU RE');
  });

  test('les accents sont retirés sans toucher au reste', () {
    expect(withoutDiacritics('Bénou Ré'), 'Benou Re');
    expect(withoutDiacritics('Thérèse Eliseman'), 'Therese Eliseman');
    expect(withoutDiacritics('Maître'), 'Maitre');
    expect(withoutDiacritics("l'Orient"), "l'Orient");
  });

  test('le document Firestore ne remplace que les champs renseignés', () {
    final merged = LodgeConfig.benouRe.mergedWith({
      'lodgeName': 'Les Trois Palmiers',
      'lodgeNumber': '12',
      // Champs absents : orient, lieu de réunion, dossiers Drive.
    });
    expect(merged.name, 'Les Trois Palmiers');
    expect(merged.formalTitleUpper, 'Respectable Loge LES TROIS PALMIERS N°12');
    expect(merged.orient, LodgeConfig.benouRe.orient);
    expect(merged.defaultMeetingPlace, LodgeConfig.benouRe.defaultMeetingPlace);
  });

  test('une valeur vide ou du mauvais type garde le repli du flavor', () {
    final merged = LodgeConfig.benouRe.mergedWith({
      'lodgeName': '   ',
      'lodgeNumber': 7,
      'driveParentFolderId': null,
    });
    expect(merged.name, LodgeConfig.benouRe.name);
    expect(merged.number, LodgeConfig.benouRe.number);
    expect(
      merged.driveParentFolderId,
      LodgeConfig.benouRe.driveParentFolderId,
    );
  });

  test('les dossiers Drive se remplacent grade par grade', () {
    final merged = LodgeConfig.benouRe.mergedWith({
      'libraryFolders': {
        'Rituels': {'Apprenti': 'nouvel-id'},
      },
    });
    expect(merged.libraryFolders['Rituels']!['Apprenti'], 'nouvel-id');
    // Les grades et les types non redéfinis restent ceux du flavor.
    expect(
      merged.libraryFolders['Rituels']!['Maître'],
      LodgeConfig.benouRe.libraryFolders['Rituels']!['Maître'],
    );
    expect(
      merged.libraryFolders['Architecture'],
      LodgeConfig.benouRe.libraryFolders['Architecture'],
    );
  });

  test('la configuration du flavor est intacte après une fusion', () {
    LodgeConfig.benouRe.mergedWith({
      'libraryFolders': {
        'Rituels': {'Apprenti': 'nouvel-id'},
      },
    });
    expect(
      LodgeConfig.benouRe.libraryFolders['Rituels']!['Apprenti'],
      '1HUMlA7LU4p2H2q2irhzR0d9ZbrW0sqhR',
    );
  });
}
