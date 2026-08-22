import 'package:benou_re/models/presence_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PresenceLink link({String memberName = '', String recipientName = ''}) {
    final now = DateTime.now();
    return PresenceLink(
      id: 't1',
      sessionId: 's1',
      sessionLabel: '',
      sessionDateLabel: '',
      sessionType: '',
      sessionDegreeLabel: '',
      hasAgape: false,
      memberName: memberName,
      recipientName: recipientName,
      expiresAt: now,
      createdAt: now,
    );
  }

  group('displayName', () {
    test('Flux A : reprend le nom du membre', () {
      expect(link(memberName: 'Jean DUPONT').displayName, 'Jean DUPONT');
    });

    test(
      'Flux B (dignitaire venant seul, formulaire Présent/Absent) : '
      'se rabat sur le nom du destinataire',
      () {
        expect(
          link(recipientName: 'Marie MARTIN').displayName,
          'Marie MARTIN',
        );
      },
    );
  });
}
