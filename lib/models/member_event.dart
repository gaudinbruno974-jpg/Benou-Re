// Historique d'un membre : élévations de grade et changements de statut
// (démission, mise en sommeil, radiation, réintégration...), datés — pour
// distinguer, dans le Rapport pour la Grande Loge, ce qui a réellement
// bougé sur une période donnée plutôt que la seule photo actuelle. Un seul
// mécanisme générique pour les changements de statut (fromValue/toValue)
// plutôt qu'un type par cas particulier : la liste des statuts possibles
// reste celle déjà utilisée sur la fiche membre (voir member_edit_screen.dart),
// aucune valeur figée en dur ici.
//
// L'entrée dans la Loge n'a volontairement pas son propre type d'événement :
// `Member.entryDate` en est déjà la source unique (voir member.dart),
// affichée en première ligne de la frise sans document dupliqué.
import '../utils/fr_date.dart';

const String kMemberEventElevation = 'elevation';
const String kMemberEventStatusChange = 'statusChange';

class MemberEvent {
  final String id;
  final String memberId;

  /// [kMemberEventElevation] / [kMemberEventStatusChange].
  final String type;

  /// Date de l'événement, `dd/MM/yyyy` — même convention que les autres
  /// champs de date de la fiche membre (voir tryParseFrDate).
  final String date;

  /// Valeur avant l'événement (grade ou statut) — vide si inconnue (import,
  /// première élévation enregistrée sans historique antérieur).
  final String fromValue;

  /// Valeur après l'événement — c'est aussi la valeur appliquée au grade/
  /// statut courant du membre au moment de l'enregistrement.
  final String toValue;

  final String note;

  const MemberEvent({
    required this.id,
    required this.memberId,
    required this.type,
    required this.date,
    this.fromValue = '',
    required this.toValue,
    this.note = '',
  });

  DateTime? get dateTime => tryParseFrDate(date);

  factory MemberEvent.fromMap(String id, Map<String, dynamic> map) {
    return MemberEvent(
      id: id,
      memberId: (map['memberId'] ?? '') as String,
      type: (map['type'] ?? kMemberEventStatusChange) as String,
      date: (map['date'] ?? '') as String,
      fromValue: (map['fromValue'] ?? '') as String,
      toValue: (map['toValue'] ?? '') as String,
      note: (map['note'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'memberId': memberId,
    'type': type,
    'date': date,
    'fromValue': fromValue,
    'toValue': toValue,
    'note': note,
  };
}
