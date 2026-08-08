import 'package:benou_re/models/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("l'e-mail de contact sert d'identifiant tant qu'il n'y en a pas d'autre",
      () {
    const m = Member(id: '1', email: 'Frere@Loge.com');
    expect(m.effectiveLoginEmail, 'Frere@Loge.com');
  });

  test("l'e-mail de connexion l'emporte sur l'e-mail de contact", () {
    const m = Member(
      id: '1',
      email: 'nouveau@loge.com',
      loginEmail: 'ancien@loge.com',
    );
    expect(m.effectiveLoginEmail, 'ancien@loge.com');
  });

  test('le rattachement au compte Firebase survit à un aller-retour Firestore',
      () {
    const m = Member(id: '1', authUid: 'uid-42', loginEmail: 'a@loge.com');
    final back = Member.fromMap('1', m.toMap());
    expect(back.authUid, 'uid-42');
    expect(back.loginEmail, 'a@loge.com');
  });

  test('les offices proposés couvrent ceux qui donnent des droits', () {
    expect(kFunctions, contains('Vénérable Maître'));
    expect(kFunctions, contains('Secrétaire'));
    expect(kFunctions, contains('Trésorier'));
    expect(kFunctions.first, 'Aucun');
  });
}
