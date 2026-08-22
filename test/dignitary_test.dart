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

  group('dignitariesToAnnounce', () {
    const dignitaryVenerable = Dignitary(
      id: 'd4',
      firstName: 'Jean',
      lastName: 'DUPUIS',
      title: 'Vénérable Maître',
      lodge: 'Les Trois Vertus',
      protocolRank: 9,
    );

    test(
      'un dignitaire sans office (à l’Orient par défaut) est annoncé',
      () {
        final result = dignitariesToAnnounce(
          sessionWith(dignitaryIds: const ['d1']),
          const [dignitaryNoRole],
        );
        expect(result, [dignitaryNoRole]);
      },
    );

    test(
      'un dignitaire avec un office ce jour-là entre avec le collège des '
      'officiers et n’est pas annoncé',
      () {
        final result = dignitariesToAnnounce(
          sessionWith(
            dignitaryIds: const ['d2'],
            dignitaryRoles: const {'d2': 'Second Surveillant'},
          ),
          const [dignitaryColonneNord],
        );
        expect(result, isEmpty);
      },
    );

    test(
      'le Vénérable Maître passe toujours en premier, avant le rang '
      'protocolaire',
      () {
        final result = dignitariesToAnnounce(
          sessionWith(dignitaryIds: const ['d1', 'd4']),
          const [dignitaryNoRole, dignitaryVenerable], // d1 : rang non défini
        );
        expect(result.first, dignitaryVenerable);
      },
    );

    test('à défaut de Vénérable Maître, le tri par rang protocolaire reste inchangé', () {
      const higherRank = Dignitary(id: 'd5', lastName: 'A', protocolRank: 1);
      const lowerRank = Dignitary(id: 'd6', lastName: 'B', protocolRank: 2);
      final result = dignitariesToAnnounce(
        sessionWith(dignitaryIds: const ['d6', 'd5']),
        const [lowerRank, higherRank],
      );
      expect(result, [higherRank, lowerRank]);
    });
  });

  group('dignitaryComesAlone', () {
    test('vrai pour un rang 1 ou 2 (officier d\'obédience)', () {
      expect(
        dignitaryComesAlone(const Dignitary(id: 'd7', protocolRank: 1)),
        isTrue,
      );
      expect(
        dignitaryComesAlone(const Dignitary(id: 'd8', protocolRank: 2)),
        isTrue,
      );
    });

    test(
      'faux pour un rang 3 ou supérieur (Vénérable amenant une délégation)',
      () {
        expect(
          dignitaryComesAlone(const Dignitary(id: 'd9', protocolRank: 3)),
          isFalse,
        );
        expect(
          dignitaryComesAlone(const Dignitary(id: 'd10', protocolRank: 5)),
          isFalse,
        );
      },
    );

    test('faux par défaut quand le rang n\'est pas renseigné', () {
      expect(
        dignitaryComesAlone(const Dignitary(id: 'd11')),
        isFalse,
      );
    });
  });
}
