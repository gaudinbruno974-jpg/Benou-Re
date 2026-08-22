import 'package:benou_re/config/lodge_config.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/services/treasury_document_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final defaultConfig = LodgeConfig.current;
  setUp(() {
    LodgeConfig.current = LodgeConfig.benouRe.mergedWith({
      'treasuryAssociationName': 'Les Amis de Bénou Ré',
      'treasuryRib': 'IBAN FR76 0000 0000 0000\nBIC ABCDEFGH',
    });
  });
  tearDown(() {
    LodgeConfig.current = defaultConfig;
  });

  final members = [
    const Member(
      id: 'vm',
      firstName: 'Bruno',
      lastName: 'GAUDIN',
      function: 'Vénérable Maître',
    ),
    const Member(
      id: 'tr',
      firstName: 'Sabine',
      lastName: 'COSTILLE',
      function: 'Trésorier',
      civilite: 'Sœur',
    ),
  ];

  const member = Member(
    id: 'm1',
    firstName: 'Jean',
    lastName: 'DUPONT',
    civilite: 'Frère',
    duesByYear: {
      2026: DuesYear(lodgeDues: 100, orderDues: 50),
    },
  );

  test('les objets reprennent le type de document et l\'année', () {
    expect(capitationCallSubject(2026), 'Appel de cotisation 2026');
    expect(quitusSubject(2026), 'Quitus de cotisation 2026');
  });

  group('capitationCallBody', () {
    test('salue le membre par son genre et cite les deux montants', () {
      final body = capitationCallBody(member, 2026, members);
      expect(body, contains('Mon Très Cher Frère Jean DUPONT'));
      expect(body, contains('100.00 € pour la Loge'));
      expect(body, contains('50.00 € pour l’Ordre (GLDB)'));
      expect(body, contains('150.00 €'));
    });

    test('propose une solution fraternelle en cas de difficulté de paiement', () {
      final body = capitationCallBody(member, 2026, members);
      expect(
        body,
        contains(
          'nous vous invitons à vous rapprocher en toute confiance du '
          'Vénérable Maître ou de notre Hospitalier',
        ),
      );
    });

    test('reprend le RIB et le nom de l\'association configurés pour la Loge', () {
      final body = capitationCallBody(member, 2026, members);
      expect(body, contains('Les Amis de Bénou Ré'));
      expect(body, contains('IBAN FR76 0000 0000 0000'));
      expect(body, contains('DUPONT, Jean, Cotisation 2026'));
    });

    test(
      'le mandatement cite le V∴M∴ (nom masqué) et le Trésorier, pas le Secrétaire',
      () {
        final body = capitationCallBody(member, 2026, members);
        expect(body, contains('Par mandatement du V∴M∴'));
        expect(body, contains('Bru∴ GAU∴'));
        expect(body, contains('Le S∴ Trésorier Sab∴ COS∴'));
      },
    );

    test('une Sœur reçoit la formule au féminin', () {
      const soeur = Member(
        id: 'm2',
        firstName: 'Marie',
        lastName: 'MARTIN',
        civilite: 'Sœur',
      );
      final body = capitationCallBody(soeur, 2026, members);
      expect(body, contains('Ma Bien Aimée Sœur Marie MARTIN'));
    });
  });

  group('noms de fichiers Drive', () {
    test('reprennent le type, l\'année, la civilité (F/S) et le nom', () {
      expect(
        capitationCallFileName(member, 2026),
        'Capitation 2026 - F - DUPONT Jean.pdf',
      );
      const soeur = Member(
        id: 'm5',
        firstName: 'Marie',
        lastName: 'MARTIN',
        civilite: 'Sœur',
      );
      expect(
        quitusFileName(soeur, 2026),
        'Quitus 2026 - S - MARTIN Marie.pdf',
      );
    });
  });

  group('quitusBody', () {
    test('ne cite que les lignes réellement soldées, avec leur date', () {
      const paidLodgeOnly = Member(
        id: 'm3',
        firstName: 'Paul',
        lastName: 'ROUX',
        civilite: 'Frère',
        duesByYear: {
          2026: DuesYear(
            lodgeDues: 100,
            lodgeDuesPaid: true,
            lodgeDuesPaidAmount: 100,
            lodgeDuesPaidDate: '12/01/2026',
            orderDues: 50,
          ),
        },
      );
      final body = quitusBody(paidLodgeOnly, 2026, members);
      expect(body, contains('Cotisation Loge : 100.00 € reçus le 12/01/2026.'));
      expect(body, isNot(contains('Cotisation Ordre')));
    });

    test('un quitus combiné cite les deux lignes quand les deux sont soldées', () {
      const bothPaid = Member(
        id: 'm4',
        firstName: 'Alix',
        lastName: 'BERT',
        civilite: 'Sœur',
        duesByYear: {
          2026: DuesYear(
            lodgeDues: 100,
            lodgeDuesPaid: true,
            lodgeDuesPaidAmount: 100,
            lodgeDuesPaidDate: '01/02/2026',
            orderDues: 50,
            orderDuesPaid: true,
            orderDuesPaidAmount: 50,
            orderDuesPaidDate: '03/02/2026',
          ),
        },
      );
      final body = quitusBody(bothPaid, 2026, members);
      expect(body, contains('Cotisation Loge : 100.00 € reçus le 01/02/2026.'));
      expect(
        body,
        contains('Cotisation Ordre (GLDB) : 50.00 € reçus le 03/02/2026.'),
      );
    });
  });
}
