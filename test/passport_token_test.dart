import 'package:benou_re/models/passport_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generatePassportToken produit un jeton non devinable (UUID v4)', () {
    final a = generatePassportToken();
    final b = generatePassportToken();
    expect(a, isNot(b));
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(a),
      isTrue,
    );
  });

  group('isExpired', () {
    PassportToken tokenExpiringIn(Duration delta) => PassportToken(
      id: 't1',
      memberId: 'm1',
      memberName: 'Jean DUPONT',
      lodgeName: 'Bénou Ré',
      lodgeNumber: '5',
      lodgeOrient: 'Saint-Pierre',
      lodgeObedience: 'GLDB',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      expiresAt: DateTime.now().add(delta),
    );

    test('faux tant que l\'heure limite n\'est pas atteinte', () {
      expect(tokenExpiringIn(const Duration(minutes: 30)).isExpired, isFalse);
    });

    test('vrai une fois l\'heure limite dépassée', () {
      expect(tokenExpiringIn(const Duration(minutes: -1)).isExpired, isTrue);
    });
  });
}
