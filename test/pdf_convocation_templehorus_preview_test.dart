// Aperçu manuel : génère la convocation templehorus dans le dossier temp
// pour inspection visuelle (positionnement et taille du logo de la loge).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:benou_re/config/lodge_config.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  tearDown(() {
    LodgeConfig.current = LodgeConfig.forCurrentFlavor;
  });

  test('convocation templehorus : logos + mise en page', () async {
    LodgeConfig.current = LodgeConfig.templeHorus;

    final session = Session(
      id: 's1',
      date: '2026-08-11',
      dateReprise: '2026-08-11',
      degree: 'Apprenti',
      type: 'Ordinaire',
      location: 'Temple Thérèse Eliseman à Saint-Pierre',
      sessionNumber: '1',
      extra: const {
        'travail1':
            '19h30 Ouverture des Travaux au 1er Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴.',
        'travail2': 'Appel des FF∴ et SS∴ de la loge',
        'travail3':
            'Lecture de la planche tracée de nos derniers travaux au 1er Degré symbolique.',
        'travail4': 'Lecture de la correspondance et des affaires diverses.',
        'ligneCloture':
            '5. Clôture des Travaux au 1er Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴.',
        'ordresJour': <String>[],
        'typeTenue': 'Ordinaire',
        'degreTravail': 'Apprenti',
      },
    );

    final bytes = await buildConvocationPdf(session, 1, const []);
    File(
      '${Directory.systemTemp.path}/pdf_convocation_templehorus.pdf',
    ).writeAsBytesSync(bytes);

    expect(bytes.length, greaterThan(1000));
  });
}
