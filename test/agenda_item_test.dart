// Typage des points d'ordre du jour (point simple / planche avec auteur
// identifié) — voir aussi Session.agendaItems pour la compatibilité avec
// les tenues déjà enregistrées sans ce typage.
import 'package:benou_re/models/agenda_item.dart';
import 'package:benou_re/models/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgendaItem', () {
    test('isPlanche distingue les deux types', () {
      const simple = AgendaItem(text: 'Point classique');
      const planche = AgendaItem(type: kAgendaItemPlanche, authorId: 'm1');
      expect(simple.isPlanche, false);
      expect(planche.isPlanche, true);
    });

    test('un aller-retour toMap/fromMap conserve tous les champs', () {
      const item = AgendaItem(
        text: 'Planche : « Le Silence » — présentée par Jea∴ DUP∴',
        type: kAgendaItemPlanche,
        authorId: 'm1',
        title: 'Le Silence',
      );
      final restored = AgendaItem.fromMap(item.toMap());
      expect(restored.text, item.text);
      expect(restored.type, item.type);
      expect(restored.authorId, item.authorId);
      expect(restored.title, item.title);
    });

    test('une carte sans type ni auteur redevient un point simple (valeurs par défaut)', () {
      final item = AgendaItem.fromMap(const {'text': 'Ancien point'});
      expect(item.isPlanche, false);
      expect(item.authorId, '');
    });
  });

  group('agendaPlancheLine', () {
    test('avec titre : « Planche : « Titre » — présentée par Auteur »', () {
      expect(
        agendaPlancheLine(authorDisplayName: 'Jea∴ DUP∴', title: 'Le Silence'),
        'Planche : « Le Silence » — présentée par Jea∴ DUP∴',
      );
    });

    test('sans titre : reste correct sans guillemets vides', () {
      expect(
        agendaPlancheLine(authorDisplayName: 'Jea∴ DUP∴'),
        'Planche présentée par Jea∴ DUP∴',
      );
    });

    test('un titre blanc est traité comme absent', () {
      expect(
        agendaPlancheLine(authorDisplayName: 'Jea∴ DUP∴', title: '   '),
        'Planche présentée par Jea∴ DUP∴',
      );
    });
  });

  group('Session.agendaItems', () {
    test('lit la structure typée quand elle est présente', () {
      final session = Session(
        id: 's1',
        date: '2026-01-10',
        extra: {
          'agendaItems': [
            {'text': 'Point A', 'type': kAgendaItemSimple},
            {
              'text': 'Planche',
              'type': kAgendaItemPlanche,
              'authorId': 'm1',
              'title': 'X',
            },
          ],
        },
      );
      expect(session.agendaItems.length, 2);
      expect(session.agendaItems[1].isPlanche, true);
      expect(session.agendaItems[1].authorId, 'm1');
    });

    test(
      "une tenue enregistrée avant ce typage (ordresJour en texte libre) "
      "se replie sur des points simples, sans erreur",
      () {
        final session = Session(
          id: 's1',
          date: '2026-01-10',
          extra: {
            'ordresJour': ['Lecture de planche à l\'ancienne', 'Autre point'],
          },
        );
        final items = session.agendaItems;
        expect(items.length, 2);
        expect(items.every((i) => !i.isPlanche), true);
        expect(items.map((i) => i.text), [
          'Lecture de planche à l\'ancienne',
          'Autre point',
        ]);
      },
    );

    test('aucun ordre du jour renseigné : liste vide, pas de crash', () {
      final session = Session(id: 's1', date: '2026-01-10');
      expect(session.agendaItems, isEmpty);
    });
  });
}
