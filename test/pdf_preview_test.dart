import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/pdf_service.dart';

// Aperçu manuel : génère les 3 PDF dans /tmp pour inspection visuelle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  test('génère les 3 PDF de démonstration', () async {
    final members = [
      const Member(
          id: 'm1',
          firstName: 'Bruno',
          lastName: 'GAUDIN',
          function: 'Vénérable Maître',
          grade: 'Maitre'),
      const Member(
          id: 'm2',
          firstName: 'Sophie',
          lastName: 'MARTIN',
          function: 'Secrétaire',
          grade: 'Maitre'),
      const Member(
          id: 'm3',
          firstName: 'Jean',
          lastName: 'DUPONT',
          function: 'Orateur',
          grade: 'Maitre'),
      const Member(
          id: 'm4',
          firstName: 'Pierre',
          lastName: 'DURAND',
          function: 'Trésorier',
          grade: 'Maitre'),
      const Member(
          id: 'm5', firstName: 'Marc', lastName: 'PETIT', grade: 'Apprenti'),
    ];
    final visitors = [
      const Visitor(
          id: 'v1',
          firstName: 'Paul',
          lastName: 'BERNARD',
          lodge: 'Les Amis Réunis',
          orient: 'Saint-Denis',
          function: 'Premier Surveillant'),
      const Visitor(
          id: 'v2',
          firstName: 'Luc',
          lastName: 'MOREAU',
          lodge: 'La Fraternité',
          orient: 'Le Port'),
    ];

    final dignitaries = [
      const Dignitary(
          id: 'd1',
          firstName: 'Alain',
          lastName: 'ROUSSEAU',
          title: 'Grand Maître Adjoint',
          lodge: 'Les Cœurs Réunis',
          obedience: 'GLDB',
          protocolRank: 1),
      const Dignitary(
          id: 'd2',
          firstName: 'Nadia',
          lastName: 'FONTAINE',
          title: 'Représentante de la R∴L∴ Concorde',
          lodge: 'Concorde'),
    ];

    final session = Session(
      id: 's1',
      date: '2026-03-14',
      dateReprise: '2026-03-14',
      degree: 'Apprenti',
      type: 'Ordinaire',
      location: 'Temple Thérèse Eliseman à Saint-Pierre',
      sessionNumber: '128',
      vmName: 'Bruno GAUDIN',
      presentIds: const ['m1', 'm2', 'm3', 'm4'],
      excusedIds: const ['m5'],
      visitorIds: const ['v1', 'v2'],
      troncAmount: 42.5,
      visitorRoles: const {'v1': 'Premier Surveillant'},
      dignitaryIds: const ['d1', 'd2'],
      dignitaryRoles: const {'d2': 'Second Surveillant'},
      extra: const {
        'travail1': 'Ouverture des travaux au 1er degré',
        'travail2': 'Lecture et adoption de la planche précédente',
        'travail3': 'Planche du F∴ Jean DUPONT : Le symbolisme du pavé mosaïque',
        'travail4': 'Circulation du sac aux propositions',
        'ligneCloture': 'Clôture des travaux',
        'ordresJour': ['Questions diverses'],
        'plancheTravauxNotes': [
          '',
          'Planche adoptée à l’unanimité.',
          'Riche débat sur la dualité.',
          '',
        ],
        'typeTenue': 'Ordinaire',
        'degreTravail': 'Apprenti',
      },
    );

    final convoc = await buildConvocationPdf(session, 128);
    final emarg =
        await buildEmargementPdf(session, members, visitors, dignitaries);
    final planche = await buildPlancheTraceePdf(
        session, members, visitors, dignitaries, 128);

    final outDir = Directory.systemTemp;
    File('${outDir.path}/pdf_convocation.pdf').writeAsBytesSync(convoc);
    File('${outDir.path}/pdf_emargement.pdf').writeAsBytesSync(emarg);
    File('${outDir.path}/pdf_planche.pdf').writeAsBytesSync(planche);

    expect(convoc.length, greaterThan(1000));
    expect(emarg.length, greaterThan(1000));
    expect(planche.length, greaterThan(1000));
  });
}
