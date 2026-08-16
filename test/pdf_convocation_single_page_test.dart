// Vérifie que la convocation PDF tient toujours sur une seule page, même
// quand l'ordre du jour est long au point de déborder à pleine échelle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:benou_re/models/session.dart';
import 'package:benou_re/services/pdf_service.dart';

/// Compte les objets `/Type /Page` (pages individuelles) dans un PDF non
/// compressé en flux d'objets, en excluant `/Type /Pages` (le nœud racine).
/// Le paquet `pdf` (mode par défaut) écrit la structure du document en xref
/// classique, donc ce comptage textuel est fiable pour ces tests.
int _countPdfPages(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  final matches = RegExp(r'/Type\s*/Page(?!s)').allMatches(text);
  return matches.length;
}

Session _sessionWithAgenda(List<String> ordresJour) {
  return Session(
    id: 's1',
    date: '2026-03-14',
    dateReprise: '2026-03-14',
    degree: 'Apprenti',
    type: 'Ordinaire',
    location: 'Temple Thérèse Eliseman à Saint-Pierre',
    sessionNumber: '128',
    vmName: 'Bruno GAUDIN',
    extra: {
      'travail1': 'Ouverture des travaux au 1er degré',
      'travail2': 'Lecture et adoption de la planche précédente',
      'travail3': 'Planche du F∴ Jean DUPONT : Le symbolisme du pavé mosaïque',
      'travail4': 'Circulation du sac aux propositions',
      'ligneCloture': 'Clôture des travaux',
      'ordresJour': ordresJour,
      'typeTenue': 'Ordinaire',
      'degreTravail': 'Apprenti',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  test('ordre du jour court : une page (non-régression)', () async {
    final session = _sessionWithAgenda(['Questions diverses']);
    final bytes = await buildConvocationPdf(session, 128, const []);
    File(
      '${Directory.systemTemp.path}/pdf_convocation_court.pdf',
    ).writeAsBytesSync(bytes);
    expect(_countPdfPages(bytes), 1);
  });

  test(
    'ordre du jour long (déborde à pleine échelle) : reste sur une page',
    () async {
      final longItems = [
        'Ouverture des travaux au 1er degré et vérification du Temple',
        'Lecture et adoption de la planche de la tenue précédente',
        'Circulation du tronc de la veuve et du sac aux propositions',
        'Réception et accueil des visiteurs et visiteuses',
        'Planche du F∴ Jean DUPONT : le symbolisme du pavé mosaïque',
        'Planche de la S∴ Sophie MARTIN : les outils de l\'apprenti',
        'Instruction du grade sur les colonnes du Temple',
        'Correspondance reçue de la Grande Loge de Bourbon',
        'Point sur la trésorerie et les cotisations en retard',
        'Préparation de la prochaine tenue et de l\'agenda annuel',
        'Questions diverses et propositions de travaux futurs',
        'Annonce de la prochaine tenue et de son ordre du jour',
      ];
      final session = _sessionWithAgenda(longItems);
      final bytes = await buildConvocationPdf(session, 128, const []);
      File(
        '${Directory.systemTemp.path}/pdf_convocation_long.pdf',
      ).writeAsBytesSync(bytes);
      expect(_countPdfPages(bytes), 1);
    },
  );
}
