import 'package:benou_re/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getMasonicDate (calendrier égyptien, système Ambelain)', () {
    test('1er Thot : le Nouvel An a lieu le 29 août', () {
      expect(
        getMasonicDate(DateTime(2026, 8, 29)),
        'Le 1er jour du mois de Thot de l’An 3318 A∴E∴',
      );
    });

    test('dernier jour de Thot (30 jours exacts)', () {
      expect(
        getMasonicDate(DateTime(2026, 9, 27)),
        'Le 30ème jour du mois de Thot de l’An 3318 A∴E∴',
      );
    });

    test('premier jour de Paophi, juste après Thot', () {
      expect(
        getMasonicDate(DateTime(2026, 9, 28)),
        'Le 1er jour du mois de Paophi de l’An 3318 A∴E∴',
      );
    });

    test('les 5 jours Épagomènes (24-28 août) précèdent le Nouvel An', () {
      expect(
        getMasonicDate(DateTime(2026, 8, 24)),
        'Le 1er jour Épagomène (Naissance d’Osiris) de l’An 3317 A∴E∴',
      );
      expect(
        getMasonicDate(DateTime(2026, 8, 26)),
        'Le 3ème jour Épagomène (Naissance de Seth) de l’An 3317 A∴E∴',
      );
      expect(
        getMasonicDate(DateTime(2026, 8, 28)),
        'Le 5ème jour Épagomène (Naissance de Nephthys) de l’An 3317 A∴E∴',
      );
    });

    test('avant le 24 août : toujours dans l’année égyptienne précédente', () {
      expect(
        getMasonicDate(DateTime(2026, 1, 1)),
        'Le 6ème jour du mois de Tybi de l’An 3317 A∴E∴',
      );
    });

    test('dernier jour de Mesori, juste avant les Épagomènes suivants', () {
      expect(
        getMasonicDate(DateTime(2027, 8, 23)),
        'Le 30ème jour du mois de Mesori de l’An 3318 A∴E∴',
      );
    });

    test(
      'après une année bissextile, les mois chaînés depuis Thot dérivent '
      'd’un jour par rapport à la table de calendrier fixe (29 février '
      'compté dans le décompte, comme les 12 mois précédents)',
      () {
        // Sans année bissextile, Pharmouthi commencerait le 27 mars (comme
        // Tybi/Mekhir/etc. l'ont fait) ; le 29 février 2028 avance ce début
        // d'un jour, au 26 mars — cohérent avec un chaînage de blocs de 30
        // jours exacts depuis le seul point fixe (29 août).
        expect(
          getMasonicDate(DateTime(2028, 3, 26)),
          'Le 1er jour du mois de Pharmouthi de l’An 3319 A∴E∴',
        );
        expect(
          getMasonicDate(DateTime(2028, 3, 27)),
          'Le 2ème jour du mois de Pharmouthi de l’An 3319 A∴E∴',
        );
      },
    );

    test('date nulle : repli explicite', () {
      expect(getMasonicDate(null), 'Date inconnue');
    });
  });

  group('getSothiacDate (calendrier égyptien, voie sothiaque/nilotique)', () {
    // Nouvel An (1er Thot) au lever héliaque de Sirius, conventionnellement
    // le 19 juillet julien — voir calendrier-egyptien-du-rapmm.pdf (fourni
    // par l'utilisateur) pour les bornes et l'orthographe des mois, qui
    // diffère de la graphie civile d'Ambelain pour 4 des 12 mois (Pakhous/
    // Psyrie/Khaoiak/Mekhein, et non Pakhons/Payni/Khoiak/Mekhir).
    test('1er Thot : le Nouvel An a lieu le 19 juillet', () {
      expect(
        getSothiacDate(DateTime(2026, 7, 19)),
        'Le 1er jour du mois de Thot de l’An 3318 E∴S∴',
      );
    });

    test('dernier jour de Thot (30 jours exacts)', () {
      expect(
        getSothiacDate(DateTime(2026, 8, 17)),
        'Le 30ème jour du mois de Thot de l’An 3318 E∴S∴',
      );
    });

    test('premier jour de Paophi, juste après Thot', () {
      expect(
        getSothiacDate(DateTime(2026, 8, 18)),
        'Le 1er jour du mois de Paophi de l’An 3318 E∴S∴',
      );
    });

    test('les 5 jours Épagomènes (14-18 juillet) précèdent le Nouvel An', () {
      expect(
        getSothiacDate(DateTime(2026, 7, 14)),
        'Le 1er jour Épagomène (Naissance d’Osiris) de l’An 3317 E∴S∴',
      );
      expect(
        getSothiacDate(DateTime(2026, 7, 16)),
        'Le 3ème jour Épagomène (Naissance de Seth) de l’An 3317 E∴S∴',
      );
      expect(
        getSothiacDate(DateTime(2026, 7, 18)),
        'Le 5ème jour Épagomène (Naissance de Nephthys) de l’An 3317 E∴S∴',
      );
    });

    test('avant le 14 juillet : toujours dans l’année égyptienne précédente', () {
      expect(
        getSothiacDate(DateTime(2026, 1, 1)),
        'Le 17ème jour du mois de Mekhein de l’An 3317 E∴S∴',
      );
    });

    test('dernier jour de Mesori, juste avant les Épagomènes suivants', () {
      expect(
        getSothiacDate(DateTime(2027, 7, 13)),
        'Le 30ème jour du mois de Mesori de l’An 3318 E∴S∴',
      );
    });

    test('aujourd’hui (21 septembre 2026), vérifié avec l’utilisateur', () {
      expect(
        getSothiacDate(DateTime(2026, 9, 21)),
        'Le 5ème jour du mois d’Athyr de l’An 3318 E∴S∴',
      );
    });

    test('date nulle : repli explicite', () {
      expect(getSothiacDate(null), 'Date inconnue');
    });
  });
}
