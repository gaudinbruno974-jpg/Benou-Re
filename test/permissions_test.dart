import 'package:flutter_test/flutter_test.dart';

import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';

void main() {
  test('les droits tenues ignorent casse et accents', () {
    expect(
      canEditSessions(const Member(id: '1', function: 'Vénérable Maître')),
      isTrue,
    );
    expect(
      canEditSessions(const Member(id: '2', function: 'venerable maitre')),
      isTrue,
    );
    expect(canEditSessions(const Member(id: '3', function: 'Orateur')), isFalse);
    expect(
      canEditSessions(const Member(id: '4', function: 'Trésorier')),
      isFalse,
    );
  });

  test('les droits trésorerie couvrent les graphies de Trésorier', () {
    expect(
      canEditTreasury(const Member(id: '1', function: 'Trésorier')),
      isTrue,
    );
    expect(
      canEditTreasury(const Member(id: '2', function: 'tresorier')),
      isTrue,
    );
    expect(
      canEditTreasury(const Member(id: '3', function: 'Aucun', isAdmin: true)),
      isTrue,
    );
    expect(canEditTreasury(const Member(id: '4', function: 'Orateur')), isFalse);
  });

  test('les grades sont ramenés sur une graphie unique', () {
    expect(normalizeGrade('Maitre'), kMaitre);
    expect(normalizeGrade('maître'), kMaitre);
    expect(normalizeGrade('Compagnon'), kCompagnon);
    expect(normalizeGrade(null), '');
  });

  test('le rang du degré suit la hiérarchie', () {
    expect(Session.degreeRank('Maitre'), 3);
    expect(Session.degreeRank(kMaitre), 3);
    expect(Session.degreeRank(kCompagnon), 2);
    expect(Session.degreeRank(kApprenti), 1);
  });

  test(
    'la vue d\'annonce des Dignitaires est ouverte au bureau et au M.C.',
    () {
      expect(
        canViewDignitaryAnnounce(
          const Member(id: '1', function: 'Vénérable Maître'),
        ),
        isTrue,
      );
      expect(
        canViewDignitaryAnnounce(
          const Member(id: '2', function: 'Maître des Cérémonies'),
        ),
        isTrue,
      );
      expect(
        canViewDignitaryAnnounce(
          const Member(id: '3', function: 'maitre des ceremonies'),
        ),
        isTrue,
      );
      expect(
        canViewDignitaryAnnounce(const Member(id: '4', isAdmin: true)),
        isTrue,
      );
      expect(
        canViewDignitaryAnnounce(const Member(id: '5', function: 'Orateur')),
        isFalse,
      );
      expect(canViewDignitaryAnnounce(null), isFalse);
    },
  );

  test(
    'isVenerableMaitre est plus restrictif que canEditSessions : exclut le Secrétaire',
    () {
      expect(
        isVenerableMaitre(const Member(id: '1', function: 'Vénérable Maître')),
        isTrue,
      );
      expect(
        isVenerableMaitre(const Member(id: '2', function: 'venerable maitre')),
        isTrue,
      );
      expect(
        isVenerableMaitre(const Member(id: '3', function: 'Aucun', isAdmin: true)),
        isTrue,
      );
      expect(
        isVenerableMaitre(const Member(id: '4', function: 'Secrétaire')),
        isFalse,
      );
      expect(isVenerableMaitre(null), isFalse);
    },
  );
}
