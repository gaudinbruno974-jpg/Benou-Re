import 'package:benou_re/config/lodge_config.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/agape_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';

Session _session(Map<String, dynamic> extra) => Session.fromMap('s1', {
      'date': '2026-03-14',
      ...extra,
    });

void main() {
  const members = [
    Member(id: 'm1', firstName: 'Bruno', lastName: 'GAUDIN'),
    Member(id: 'm2', firstName: 'Alice', lastName: 'MARTIN'),
  ];
  const visitors = [
    Visitor(
      id: 'v1',
      firstName: 'Jean',
      lastName: 'DUPONT',
      obedience: 'GLDF',
      lodge: 'Les Trois Palmiers',
    ),
  ];

  test('seules les Tenues avec médaille sont concernées', () {
    expect(hasAgapeMedaille(_session({'typeRepas': 'Agape avec médaille'})),
        isTrue);
    expect(hasAgapeMedaille(_session({'typeRepas': 'Agape partage'})), isFalse);
    expect(hasAgapeMedaille(_session({'agapeType': 'Agape avec medaille'})),
        isTrue);
  });

  test('les payeurs reprennent les membres puis les invités cochés', () {
    final session = _session({
      'typeRepas': 'Agape avec médaille',
      'montantMedaille': 25,
      'agapeIds': ['m1'],
      'visitorAgapeIds': ['v1'],
    });
    final payers = agapePayers(session, members, visitors);
    expect(payers.map((p) => p.id), ['m1', 'v1']);
    expect(payers.first.obedience, LodgeConfig.current.obedienceAcronym);
    expect(payers.first.lodge, LodgeConfig.current.name);
    expect(payers.last.obedience, 'GLDF');
    expect(payers.last.lodge, 'Les Trois Palmiers');
  });

  test('le total ne compte que les signatures enregistrées', () {
    final session = _session({
      'typeRepas': 'Agape avec médaille',
      'montantMedaille': 25,
      'agapeIds': ['m1', 'm2'],
      'visitorAgapeIds': ['v1'],
      'agapePaymentSignatures': {'m1': 'data:image/png;base64,AAA'},
    });
    expect(agapeMedailleAmount(session), 25);
    expect(agapeCollectedTotal(session, members, visitors), 25);
  });
}
