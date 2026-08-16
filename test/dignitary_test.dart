// Modèle Dignitary (aller-retour Firestore) et fusion de la narration de la
// planche tracée avec les Visiteurs ayant pris un office à l'Orient.
import 'package:flutter_test/flutter_test.dart';

import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/pdf_service.dart';

void main() {
  test('Dignitary : toMap/fromMap conservent tous les champs', () {
    const d = Dignitary(
      id: 'd1',
      firstName: 'Alain',
      lastName: 'ROUSSEAU',
      title: 'Grand Maître Adjoint',
      lodge: 'Les Cœurs Réunis',
      orient: 'Saint-Denis',
      obedience: 'GLDB',
      email: 'alain@example.com',
      phone: '0600000000',
      protocolRank: 1,
    );
    final restored = Dignitary.fromMap('d1', d.toMap());
    expect(restored.fullName, 'Alain ROUSSEAU');
    expect(restored.title, 'Grand Maître Adjoint');
    expect(restored.lodge, 'Les Cœurs Réunis');
    expect(restored.protocolRank, 1);
  });

  test('Dignitary : protocolRank absent reste null après aller-retour', () {
    const d = Dignitary(id: 'd2', firstName: 'Nadia', lastName: 'FONTAINE');
    final restored = Dignitary.fromMap('d2', d.toMap());
    expect(restored.protocolRank, isNull);
  });

  Session sessionWith({
    List<String> visitorIds = const [],
    Map<String, String> visitorRoles = const {},
    List<String> dignitaryIds = const [],
    Map<String, String> dignitaryRoles = const {},
  }) {
    return Session(
      id: 's1',
      date: '2026-03-14',
      dateReprise: '2026-03-14',
      degree: 'Apprenti',
      sessionNumber: '128',
      vmName: 'Bruno GAUDIN',
      visitorIds: visitorIds,
      visitorRoles: visitorRoles,
      dignitaryIds: dignitaryIds,
      dignitaryRoles: dignitaryRoles,
      extra: const {'typeTenue': 'Ordinaire', 'degreTravail': 'Apprenti'},
    );
  }

  const visitorWithOffice = Visitor(
    id: 'v1',
    firstName: 'Paul',
    lastName: 'BERNARD',
    lodge: 'Les Amis Réunis',
  );

  const dignitaryNoRole = Dignitary(
    id: 'd1',
    firstName: 'Alain',
    lastName: 'ROUSSEAU',
    title: 'Grand Maître Adjoint',
    lodge: 'Les Cœurs Réunis',
  );

  const dignitaryColonneNord = Dignitary(
    id: 'd2',
    firstName: 'Nadia',
    lastName: 'FONTAINE',
    lodge: 'Concorde',
  );

  const dignitaryOrateur = Dignitary(
    id: 'd3',
    firstName: 'Marc',
    lastName: 'LEROY',
    title: 'Ancien Vénérable',
  );

  test(
    'sans dignitaire : la narration reste identique au comportement historique (non-régression)',
    () {
      final withVisitorOnly = buildPlancheTraceeText(
        sessionWith(
          visitorIds: const ['v1'],
          visitorRoles: const {'v1': 'Secrétaire'},
        ),
        const [],
        const [visitorWithOffice],
        const [],
        128,
      );
      final withVisitorAndEmptyDignitaries = buildPlancheTraceeText(
        sessionWith(
          visitorIds: const ['v1'],
          visitorRoles: const {'v1': 'Secrétaire'},
        ),
        const [],
        const [visitorWithOffice],
        const [], // liste de dignitaires vide, comme avant l'ajout de la fonctionnalité
        128,
      );
      expect(withVisitorAndEmptyDignitaries, withVisitorOnly);
      expect(
        withVisitorOnly,
        contains(
          'A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : Pau∴ BER∴ (Secrétaire – Les Amis Réunis).',
        ),
      );
    },
  );

  test(
    'un dignitaire sans office pris ce jour n\'est pas cité (pas de repli par défaut à l\'Orient)',
    () {
      final text = buildPlancheTraceeText(
        sessionWith(
          visitorIds: const ['v1'],
          visitorRoles: const {'v1': 'Secrétaire'},
          dignitaryIds: const ['d1'],
        ),
        const [],
        const [visitorWithOffice],
        const [dignitaryNoRole],
        128,
      );
      expect(
        text,
        contains(
          'A l’Orient, sont venus soutenir nos travaux les dignitaires suivants : '
          'Pau∴ BER∴ (Secrétaire – Les Amis Réunis).',
        ),
      );
      expect(text, isNot(contains('Ala∴ ROU∴')));
    },
  );

  test(
    'un dignitaire avec un office hors Orient reçoit sa propre phrase de placement',
    () {
      final text = buildPlancheTraceeText(
        sessionWith(
          dignitaryIds: const ['d2'],
          dignitaryRoles: const {'d2': 'Second Surveillant'},
        ),
        const [],
        const [],
        const [dignitaryColonneNord],
        128,
      );
      expect(
        text,
        contains(
          'Au Nord, a pris place le F∴/S∴ Nad∴ FON∴ (Concorde) en qualité de Second Surveillant.',
        ),
      );
      expect(text, isNot(contains('sont venus soutenir nos travaux')));
    },
  );

  test('un dignitaire peut être retenu comme Orateur', () {
    final text = buildPlancheTraceeText(
      sessionWith(
        dignitaryIds: const ['d3'],
        dignitaryRoles: const {'d3': 'Orateur'},
      ),
      const [],
      const [],
      const [dignitaryOrateur],
      128,
    );
    expect(
      text,
      contains('Le poste d’Orateur est occupé par le F∴/S∴ Mar∴ LER∴.'),
    );
  });
}
