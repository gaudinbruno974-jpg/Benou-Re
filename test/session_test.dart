// Suffixe de nom de fichier Drive (date + grade) ajouté aux PDF archivés
// d'une tenue (Convocation, Émargement, Planche tracée, Paiement des
// Agapes) — voir session_edit_screen.dart, sessions_screen.dart,
// agape_payment_screen.dart.
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('driveFileDateGradeSuffix', () {
    test('« jj mm aa X » avec bornes à zéro (jj/mm) et grade Apprenti', () {
      final s = Session(
        id: 's1',
        date: '2024-01-05',
        dateReprise: '2024-01-05',
        degree: kApprenti,
      );
      expect(s.driveFileDateGradeSuffix, ' 05 01 24 A');
    });

    test('Compagnon -> C, Maître -> M', () {
      final compagnon = Session(
        id: 's1',
        date: '2024-10-27',
        dateReprise: '2024-10-27',
        degree: kCompagnon,
      );
      final maitre = Session(
        id: 's2',
        date: '2024-10-27',
        dateReprise: '2024-10-27',
        degree: kMaitre,
      );
      expect(compagnon.driveFileDateGradeSuffix, ' 27 10 24 C');
      expect(maitre.driveFileDateGradeSuffix, ' 27 10 24 M');
    });

    test('tolère une graphie non normalisée du grade (ex. "maitre" sans accent)', () {
      final s = Session(
        id: 's1',
        date: '2024-10-27',
        dateReprise: '2024-10-27',
        degree: 'maitre',
      );
      expect(s.driveFileDateGradeSuffix, ' 27 10 24 M');
    });

    test('sans date renseignée : seul le grade apparaît, pas de crash', () {
      const s = Session(id: 's1', degree: kApprenti);
      expect(s.driveFileDateGradeSuffix, ' A');
    });
  });
}
