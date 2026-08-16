// Aperçu manuel : génère la convocation petitprince dans le dossier temp
// pour inspection visuelle (positionnement des logos, nom du V∴M∴).
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

  test('convocation petitprince : logos + VM réel (Olivier PAYET)', () async {
    LodgeConfig.current = LodgeConfig.petitPrince;

    final session = Session(
      id: 's1',
      date: '2026-08-11',
      dateReprise: '2026-08-11',
      degree: 'Apprenti',
      type: 'Ordinaire',
      location: 'Temple Thérèse Eliseman à Saint-Pierre',
      sessionNumber: '2',
      extra: const {
        'travail1':
            '19h30 Ouverture des Travaux au 1er Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Olivier PAYET.',
        'travail2': 'Appel des FF∴ et SS∴ de la loge',
        'travail3':
            'Lecture de la planche tracée de nos derniers travaux au 1er Degré symbolique.',
        'travail4': 'Lecture de la correspondance et des affaires diverses.',
        'ligneCloture':
            '5. Clôture des Travaux au 1er Degré symbolique du R∴A∴P∴M∴M∴ par le V∴M∴ Olivier PAYET.',
        'ordresJour': <String>[],
        'typeTenue': 'Ordinaire',
        'degreTravail': 'Apprenti',
      },
    );

    final bytes = await buildConvocationPdf(session, 2, const []);
    File(
      '${Directory.systemTemp.path}/pdf_convocation_petitprince.pdf',
    ).writeAsBytesSync(bytes);

    expect(bytes.length, greaterThan(1000));
  });

  test('convocation benoure : témoin de non-régression', () async {
    LodgeConfig.current = LodgeConfig.benouRe;

    final session = Session(
      id: 's1',
      date: '2026-08-11',
      dateReprise: '2026-08-11',
      degree: 'Apprenti',
      type: 'Ordinaire',
      location: 'Temple Thérèse Eliseman à Saint-Pierre',
      sessionNumber: '128',
      extra: const {
        'travail1': 'Ouverture des travaux au 1er degré',
        'ordresJour': <String>[],
        'typeTenue': 'Ordinaire',
        'degreTravail': 'Apprenti',
      },
    );

    final bytes = await buildConvocationPdf(session, 128, const []);
    File(
      '${Directory.systemTemp.path}/pdf_convocation_benoure_temoin.pdf',
    ).writeAsBytesSync(bytes);

    expect(bytes.length, greaterThan(1000));
  });
}
