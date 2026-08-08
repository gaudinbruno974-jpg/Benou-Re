// Paiement des Agapes : liste des personnes qui doivent régler leur médaille
// pour une Tenue, et total encaissé.
//
// Une Tenue n'est concernée que si le repas est une « Agape avec médaille » :
// c'est le seul type de repas qui donne lieu à un paiement.
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';

/// Obédience de la Loge, pour les membres.
const String kLodgeObedience = 'Grande Loge de Bourbon';

/// Nom de la Loge, pour les membres.
const String kLodgeName = 'Bénou Ré';

/// Une personne attendue aux agapes payantes d'une Tenue.
class AgapePayer {
  final String id;
  final String lastName;
  final String firstName;
  final String obedience;
  final String lodge;

  const AgapePayer({
    required this.id,
    required this.lastName,
    required this.firstName,
    required this.obedience,
    required this.lodge,
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// Vrai si la Tenue donne lieu à un paiement des agapes.
bool hasAgapeMedaille(Session session) {
  final type = session.typeRepas ?? session.agapeType;
  return foldLabel(type).contains('medaille');
}

/// Tenues concernées par le paiement des agapes, la plus récente en premier
/// (`sessionsStream` les fournit déjà triées).
List<Session> agapeMedailleSessions(List<Session> sessions) =>
    sessions.where(hasAgapeMedaille).toList();

/// Montant de la médaille à régler par personne.
num agapeMedailleAmount(Session session) =>
    session.montantMedaille ?? session.agapePrice;

/// Personnes annoncées aux agapes : membres puis invités.
List<AgapePayer> agapePayers(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) {
  return [
    for (final m in members)
      if (session.agapeIds.contains(m.id))
        AgapePayer(
          id: m.id,
          lastName: m.lastName,
          firstName: m.firstName,
          obedience: kLodgeObedience,
          lodge: kLodgeName,
        ),
    for (final v in visitors)
      if (session.visitorAgapeIds.contains(v.id))
        AgapePayer(
          id: v.id,
          lastName: v.lastName,
          firstName: v.firstName,
          obedience: v.obedience,
          lodge: v.lodge,
        ),
  ];
}

/// Total encaissé : seules les personnes ayant signé ont payé.
num agapeCollectedTotal(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
) {
  final signatures = session.agapePaymentSignatures;
  final signed = agapePayers(session, members, visitors)
      .where((p) => (signatures[p.id] ?? '').isNotEmpty)
      .length;
  return signed * agapeMedailleAmount(session);
}
