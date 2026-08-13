// Résolution du nom du V∴M∴ affiché sur les documents (planche tracée et,
// via session_edit_screen.dart, le texte par défaut de la convocation) :
// jamais un nom figé, toujours la fiche membre réelle qui porte l'office
// pour la loge active, quel que soit le flavor.
import 'package:flutter_test/flutter_test.dart';

import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/services/pdf_service.dart';

void main() {
  const blankSession = Session(id: '');

  test('sans membre ni réglage : repli générique', () {
    expect(plancheVmName(blankSession, const []), 'Vénérable Maître');
  });

  test('config/settings prioritaire sur la recherche parmi les membres', () {
    const vm = Member(
      id: 'm1',
      firstName: 'Olivier',
      lastName: 'PAYET',
      function: 'Vénérable Maître',
    );
    expect(
      plancheVmName(blankSession, const [vm], lodgeVmName: 'Nom Configuré'),
      'Nom Configuré',
    );
  });

  test(
    'sans réglage : le membre portant l\'office est retrouvé (jamais un nom figé d\'un autre flavor)',
    () {
      const other = Member(
        id: 'm0',
        firstName: 'Autre',
        lastName: 'MEMBRE',
        function: 'Orateur',
      );
      const vm = Member(
        id: 'm1',
        firstName: 'Olivier',
        lastName: 'PAYET',
        function: 'Vénérable Maître',
      );
      expect(
        plancheVmName(blankSession, const [other, vm]),
        'Olivier PAYET',
      );
    },
  );

  test('session.vmName explicite l\'emporte sur tout le reste', () {
    const vm = Member(
      id: 'm1',
      firstName: 'Olivier',
      lastName: 'PAYET',
      function: 'Vénérable Maître',
    );
    const session = Session(id: 's1', vmName: 'Nom Saisi Manuellement');
    expect(
      plancheVmName(session, const [vm], lodgeVmName: 'Nom Configuré'),
      'Nom Saisi Manuellement',
    );
  });
}
