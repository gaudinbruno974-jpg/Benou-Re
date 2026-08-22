import 'package:benou_re/models/dignitary.dart';
import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/visitor.dart';
import 'package:benou_re/services/directory_xlsx_service.dart';
import 'package:benou_re/services/xlsx_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nameKey', () {
    test('insensible à la casse et aux accents', () {
      expect(nameKey('Éliane', 'DUPONT'), nameKey('eliane', 'dupont'));
    });
  });

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

  group('export puis import ciblé sur une seule feuille', () {
    test('un membre déjà présent (même nom) est reconnu comme doublon', () {
      final bytes = buildDirectoryWorkbook(
        members: members,
        visitors: const [],
        dignitaries: const [],
      );
      final rows = parseMemberSheet(bytes, members);
      expect(rows, hasLength(1));
      expect(rows.single.existing?.id, 'm1');
      expect(rows.single.action, ImportAction.update);
      expect(rows.single.email, 'bruno@example.com');
      expect(rows.single.preferredContact, 'WhatsApp');
    });

    test('un nom absent du répertoire est proposé en création', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: visitors,
        dignitaries: const [],
      );
      final rows = parseVisitorSheet(bytes, const []);
      final row = rows.single;
      expect(row.existing, isNull);
      expect(row.action, ImportAction.create);
      expect(row.lodge, 'La Fraternelle');
    });

    test(
      "l'import ciblé sur une feuille ignore les autres feuilles présentes "
      'dans le même classeur',
      () {
        final bytes = buildDirectoryWorkbook(
          members: members,
          visitors: visitors,
          dignitaries: dignitaries,
        );
        // Le classeur contient les trois feuilles ; ne demander que les
        // dignitaires ne doit renvoyer que les dignitaires.
        final rows = parseDignitarySheet(bytes, const []);
        expect(rows, hasLength(1));
        expect(rows.single.firstName, 'Marie');
      },
    );

    test('resolve() applique la mise à jour sans toucher aux champs non exportés', () {
      final bytes = buildDirectoryWorkbook(
        members: members,
        visitors: const [],
        dignitaries: const [],
      );
      final existing = [
        members.single.copyWith(isAdmin: true, loginEmail: 'x@y.fr'),
      ];
      final rows = parseMemberSheet(bytes, existing);
      final resolved = rows.single.resolve(() => 'unused');
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
      final rows = parseMemberSheet(bytes, members);
      rows.single.action = ImportAction.skip;
      expect(rows.single.resolve(() => 'id'), isNull);
    });

    test('un dignitaire créé reprend son rang protocolaire', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: const [],
        dignitaries: dignitaries,
      );
      final rows = parseDignitarySheet(bytes, const []);
      final resolved = rows.single.resolve(() => 'd_new');
      expect(resolved?.protocolRank, 1);
      expect(resolved?.title, 'Grand Maître Adjoint');
    });

    test('les lignes vides (sans nom ni prénom) sont ignorées', () {
      final bytes = buildDirectoryWorkbook(
        members: const [],
        visitors: const [],
        dignitaries: const [],
      );
      expect(parseMemberSheet(bytes, const []), isEmpty);
      expect(parseVisitorSheet(bytes, const []), isEmpty);
      expect(parseDignitarySheet(bytes, const []), isEmpty);
    });
  });

  group('cotisation Loge / Ordre (Membres)', () {
    final year = DateTime.now().year;

    test(
      'export puis import reprend les montants de cotisation de l\'année en cours',
      () {
        final withDues = [
          members.single.withDuesForYear(
            year,
            const DuesYear(lodgeDues: 100, orderDues: 50),
          ),
        ];
        final bytes = buildDirectoryWorkbook(
          members: withDues,
          visitors: const [],
          dignitaries: const [],
        );
        final rows = parseMemberSheet(bytes, const []);
        expect(rows.single.lodgeDues, 100);
        expect(rows.single.orderDues, 50);
      },
    );

    test(
      "resolve() met à jour les montants dus sans toucher au versement déjà "
      'enregistré pour cette année',
      () {
        final bytes = buildDirectoryWorkbook(
          members: [
            members.single.withDuesForYear(
              year,
              const DuesYear(lodgeDues: 100, orderDues: 50),
            ),
          ],
          visitors: const [],
          dignitaries: const [],
        );
        final existing = [
          members.single.withDuesForYear(
            year,
            const DuesYear(
              lodgeDues: 80,
              lodgeDuesPaid: true,
              lodgeDuesPaidAmount: 80,
              lodgeDuesPaidDate: '10/01/2026',
              orderDues: 50,
            ),
          ),
        ];
        final rows = parseMemberSheet(bytes, existing);
        final resolved = rows.single.resolve(() => 'unused')!;
        final dues = resolved.duesFor(year);
        expect(dues.lodgeDues, 100); // repris du fichier importé
        expect(dues.lodgeDuesPaid, isTrue); // non exporté : conservé
        expect(dues.lodgeDuesPaidAmount, 80); // non exporté : conservé
        expect(dues.lodgeDuesPaidDate, '10/01/2026'); // non exporté : conservé
      },
    );

    test(
      'colonnes de cotisation vides : la cotisation existante n\'est pas touchée',
      () {
        // Fichier partiellement rempli par l'utilisateur (colonnes de
        // cotisation laissées vides) — contrairement à un export automatique,
        // qui écrirait "0" plutôt qu'une cellule vide (voir la table ci-dessus,
        // Member.duesFor() reposant sur un DuesYear() par défaut à zéro).
        final row = List<String>.filled(kMemberHeaders.length, '');
        row[1] = members.single.firstName;
        row[2] = members.single.lastName;
        final bytes = buildXlsx({
          kSheetMembers: [kMemberHeaders, row],
        });
        final existing = [
          members.single.withDuesForYear(
            year,
            const DuesYear(lodgeDues: 100, orderDues: 50),
          ),
        ];
        final rows = parseMemberSheet(bytes, existing);
        expect(rows.single.lodgeDues, isNull);
        expect(rows.single.orderDues, isNull);
        final resolved = rows.single.resolve(() => 'unused')!;
        expect(resolved.duesFor(year).lodgeDues, 100);
        expect(resolved.duesFor(year).orderDues, 50);
      },
    );
  });

  test('le modèle ne contient que les en-têtes, sur les trois onglets', () {
    final bytes = buildDirectoryTemplate();
    expect(parseMemberSheet(bytes, const []), isEmpty);
    expect(parseVisitorSheet(bytes, const []), isEmpty);
    expect(parseDignitarySheet(bytes, const []), isEmpty);
  });
}
