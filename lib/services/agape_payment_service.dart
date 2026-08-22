// Paiement des Agapes : liste des personnes qui doivent régler leur médaille
// pour une Tenue, et total encaissé.
//
// Une Tenue n'est concernée que si le repas est une « Agape avec médaille » :
// c'est le seul type de repas qui donne lieu à un paiement.
import '../config/lodge_config.dart';
import '../models/dignitary.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/visitor.dart';

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

/// Personnes annoncées aux agapes : membres, puis invités, puis dignitaires.
List<AgapePayer> agapePayers(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) {
  return [
    for (final m in members)
      if (session.agapeIds.contains(m.id))
        AgapePayer(
          id: m.id,
          lastName: m.lastName,
          firstName: m.firstName,
          // Sigle de l'obédience : les noms complets sont trop longs pour la
          // colonne « Loge » du PDF.
          obedience: LodgeConfig.current.obedienceAcronym,
          lodge: LodgeConfig.current.name,
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
    for (final d in dignitaries)
      if (session.dignitaryAgapeIds.contains(d.id))
        AgapePayer(
          id: d.id,
          lastName: d.lastName,
          firstName: d.firstName,
          obedience: d.obedience,
          lodge: d.lodge,
        ),
  ];
}

/// Total encaissé : seules les personnes ayant signé ont payé.
num agapeCollectedTotal(
  Session session,
  List<Member> members,
  List<Visitor> visitors,
  List<Dignitary> dignitaries,
) {
  final signatures = session.agapePaymentSignatures;
  final signed = agapePayers(session, members, visitors, dignitaries)
      .where((p) => (signatures[p.id] ?? '').isNotEmpty)
      .length;
  return signed * agapeMedailleAmount(session);
}
