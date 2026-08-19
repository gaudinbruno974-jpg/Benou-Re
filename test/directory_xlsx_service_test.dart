import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/directory_xlsx_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nameKey', () {
    test('insensible à la casse et aux accents', () {
      expect(nameKey('Éliane', 'DUPONT'), nameKey('eliane', 'dupont'));
    });
  });

  group('export puis import (aller-retour)', () {
    final members = [
      const Member(
        id: 'm1',
        civilite: 'Frère',
        firstName: 'Bruno',
        lastName: 'GAUDIN',
        grade: kMaitre,
        function: 'Vénérable Maître',
        status: 'Actif',
        email: 'bruno@example.com',
        phone: '0692000000',
        preferredContact: 'WhatsApp',
      ),
    ];
    final visitors = [
      const Visitor(
        id: 'v1',
        firstName: 'Jean',
        lastName: 'Dupont',
        lodge: 'La Fraternelle',
        obedience: 'GLNF',
      ),
    ];
    final dignitaries = [
      const Dignitary(
        id: 'd1',
        firstName: 'Marie',
        lastName: 'Martin',
        title: 'Grand Maître Adjoint',
        protocolRank: 1,
      ),
    ];

    test('un membre déjà présent (même nom) est reconnu comme doublon', () {
      final bytes = buildDirectoryWorkbook(
        members: members,
        visitors: const [],
        dignitaries: const [],
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: members,
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      expect(preview.members, hasLength(1));
      final row = preview.members.single;
      expect(row.existing?.id, 'm1');
      expect(row.action, ImportAction.update);
      expect(row.email, 'bruno@example.com');
      expect(row.preferredContact, 'WhatsApp');
    });

    test('un nom absent du répertoire est proposé en création', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: visitors,
        dignitaries: const [],
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: const [],
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      final row = preview.visitors.single;
      expect(row.existing, isNull);
      expect(row.action, ImportAction.create);
      expect(row.lodge, 'La Fraternelle');
    });

    test('resolve() applique la mise à jour sans toucher aux champs non exportés', () {
      final bytes = buildDirectoryWorkbook(
        members: members,
        visitors: const [],
        dignitaries: const [],
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: [
          members.single.copyWith(isAdmin: true, loginEmail: 'x@y.fr'),
        ],
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      final resolved = preview.members.single.resolve(() => 'unused');
      expect(resolved, isNotNull);
      expect(resolved!.isAdmin, isTrue); // non exporté : conservé
      expect(resolved.loginEmail, 'x@y.fr'); // non exporté : conservé
      expect(resolved.email, 'bruno@example.com'); // exporté : repris du fichier
    });

    test('resolve() renvoie null quand l\'action est "skip"', () {
      final bytes = buildDirectoryWorkbook(
        members: members,
        visitors: const [],
        dignitaries: const [],
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: members,
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      preview.members.single.action = ImportAction.skip;
      expect(preview.members.single.resolve(() => 'id'), isNull);
    });

    test('un dignitaire créé reprend son rang protocolaire', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: const [],
        dignitaries: dignitaries,
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: const [],
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      final resolved = preview.dignitaries.single.resolve(() => 'd_new');
      expect(resolved?.protocolRank, 1);
      expect(resolved?.title, 'Grand Maître Adjoint');
    });

    test('les lignes vides (sans nom ni prénom) sont ignorées', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: const [],
        dignitaries: const [],
      );
      final preview = parseDirectoryWorkbook(
        bytes,
        existingMembers: const [],
        existingVisitors: const [],
        existingDignitaries: const [],
      );
      expect(preview.members, isEmpty);
      expect(preview.visitors, isEmpty);
      expect(preview.dignitaries, isEmpty);
    });
  });

  test('le modèle ne contient que les en-têtes, sur les trois onglets', () {
    final bytes = buildDirectoryTemplate();
    final preview = parseDirectoryWorkbook(
      bytes,
      existingMembers: const [],
      existingVisitors: const [],
      existingDignitaries: const [],
    );
    expect(preview.members, isEmpty);
    expect(preview.visitors, isEmpty);
    expect(preview.dignitaries, isEmpty);
  });
}
