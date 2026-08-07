import 'package:benou_re/models/member.dart';
import 'package:benou_re/models/session.dart';
import 'package:benou_re/services/invitation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final members = [
    const Member(id: 'a', firstName: 'A', grade: 'Maître'),
    const Member(id: 'b', firstName: 'B', grade: 'Maitre'),
    const Member(id: 'c', firstName: 'C', grade: 'Compagnon'),
    const Member(id: 'd', firstName: 'D', grade: 'Apprenti'),
    const Member(id: 'e', firstName: 'E', grade: 'Apprenti'),
  ];

  final session = Session.fromMap('s1', {
    'date': '2026-09-15',
    'chrono': 12,
    'presentIds': ['a', 'b', 'c', 'd'],
    'agapeIds': ['a', 'c'],
  });

  test('les compteurs suivent le degré des membres présents', () {
    final counts = invitationCounts(session, members);
    expect(counts.maitres, 2);
    expect(counts.compagnons, 1);
    expect(counts.apprentis, 1);
    expect(counts.agapes, 2);
    expect(counts.total, 4);
  });

  test('le titre reprend le chrono et la date', () {
    expect(invitationTitle(session, 12), 'Tenue 12 du 15/09/2026');
  });

  test('le message Obédience liste les compteurs par degré', () {
    final text = obedienceInvitationText(session, members, 12);
    expect(text, contains('Tenue 12 du 15/09/2026'));
    expect(text, contains('Maîtres - 2'));
    expect(text, contains('Compagnons - 1'));
    expect(text, contains('Apprentis - 1'));
    expect(text, contains('Nombre - 2'));
  });

  test('le deep link WhatsApp encode le texte', () {
    expect(whatsappShareUrl('a b'), 'https://wa.me/?text=a%20b');
  });

  test('le mailto reprend destinataires, objet et corps', () {
    final url = mailtoUrl(
      recipients: ['x@y.fr', 'z@y.fr'],
      subject: 'Tenue 12',
      body: 'Bonjour',
    );
    expect(url, startsWith('mailto:x%40y.fr,z%40y.fr?'));
    expect(url, contains('subject=Tenue%2012'));
    expect(url, contains('body=Bonjour'));
  });
}
