// Génération des textes de l'Appel de cotisation et du Quitus, envoyés
// individuellement à un membre par e-mail — voir treasury_screen.dart pour
// le déclenchement et pdf_service.dart pour la version PDF jointe.
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../config/lodge_config.dart';
import '../models/civilite.dart';
import '../models/member.dart';
import '../utils/name_mask.dart';

Member? _findTreasurer(List<Member> members) =>
    members.where((m) => foldLabel(m.function).contains('tresorier')).firstOrNull;

/// Nom du V∴M∴ en charge : réglage de la Loge (`config/settings`, comme pour
/// les convocations) sinon le membre portant l'office, sans dépendre d'une
/// tenue précise — ces documents n'en sont rattachés à aucune.
String _vmName(List<Member> members, String lodgeVmName) {
  if (lodgeVmName.trim().isNotEmpty) return lodgeVmName.trim();
  final vm =
      members.where((m) => foldLabel(m.function).contains('venerable')).firstOrNull;
  return vm != null ? vm.fullName : 'Vénérable Maître';
}

/// « Mon Très Cher Frère DUPONT Jean » / « Ma Bien Aimée Sœur DUPONT Jeanne »
/// — le destinataire est nommément désigné : à la différence des convocations
/// (diffusées largement), ce courrier lui est adressé en personne.
String _greeting(Member member) {
  final name = member.fullName.isEmpty ? 'Membre' : member.fullName;
  return member.civilite == kSoeur
      ? 'Ma Bien Aimée Sœur $name'
      : 'Mon Très Cher Frère $name';
}

/// « F » / « S », pour le nom des fichiers archivés sur Drive (voir
/// capitationCallFileName / quitusFileName) — pas d'abréviation maçonnique
/// (F∴/S∴) dans un nom de fichier.
String _civiliteLetter(Member member) => member.civilite == kSoeur ? 'S' : 'F';

String _euros(num v) => '${v.toStringAsFixed(2)} €';

List<String> _signOffLines(List<Member> members, String lodgeVmName) {
  final vmName = maskPersonName(_vmName(members, lodgeVmName));
  final treasurer = _findTreasurer(members);
  final treasurerName = treasurer != null
      ? maskPersonName(treasurer.fullName)
      : 'Trésorier';
  final treasurerCivilite = civiliteAbbrev(treasurer?.civilite ?? '');
  return [
    '',
    'Par mandatement du V∴M∴ $vmName',
    'Le $treasurerCivilite Trésorier $treasurerName',
  ];
}

String capitationCallSubject(int year) => 'Appel de cotisation $year';

String capitationCallBody(
  Member member,
  int year,
  List<Member> members, {
  String lodgeVmName = '',
}) {
  final dues = member.duesFor(year);
  final lodge = LodgeConfig.current;
  final total = dues.lodgeDues + dues.orderDues;
  final rib = lodge.treasuryRib.trim();
  final association = lodge.treasuryAssociationName.trim();
  final lines = <String>[
    '${_greeting(member)},',
    '',
    'La R∴L∴ ${lodge.name} vous invite à procéder au règlement de votre '
        'cotisation $year.',
    '',
    'Le montant dû est de ${_euros(dues.lodgeDues)} pour la Loge et de '
        '${_euros(dues.orderDues)} pour l’Ordre (${lodge.obedienceAcronym}), '
        'soit un total de ${_euros(total)}.',
    '',
    if (association.isNotEmpty)
      'Merci de bien vouloir régler par virement sur le compte de '
          '$association, en indiquant la référence « ${member.lastName}, '
          '${member.firstName}, Cotisation $year ».'
    else
      'Merci de bien vouloir régler en indiquant la référence '
          '« ${member.lastName}, ${member.firstName}, Cotisation $year ».',
    if (rib.isNotEmpty) ...['', rib],
    '',
    'Pour toute information complémentaire, vous pouvez nous contacter.',
    '',
    'Si, par suite de circonstances particulières, le règlement de cette '
        'cotisation représente une difficulté, nous vous invitons à vous '
        'rapprocher en toute confiance du Vénérable Maître ou de notre '
        'Hospitalier afin qu’une solution fraternelle et discrète puisse '
        'être trouvée.',
    '',
    'Recevez, ${_greeting(member)}, nos pensées de lumière.',
    ..._signOffLines(members, lodgeVmName),
  ];
  return lines.join('\n');
}

/// Nom du fichier archivé sur Drive (voir drive_service.dart) : le
/// sous-dossier « Capitations {année} » porte déjà l'année et le type, le
/// nom du fichier reprend quand même le préfixe complet à la demande.
String capitationCallFileName(Member member, int year) =>
    'Capitation $year - ${_civiliteLetter(member)} - '
    '${member.lastName} ${member.firstName}.pdf';

String quitusFileName(Member member, int year) =>
    'Quitus $year - ${_civiliteLetter(member)} - '
    '${member.lastName} ${member.firstName}.pdf';

String quitusSubject(int year) => 'Quitus de cotisation $year';

String quitusBody(
  Member member,
  int year,
  List<Member> members, {
  String lodgeVmName = '',
}) {
  final dues = member.duesFor(year);
  final lodge = LodgeConfig.current;
  final df = DateFormat('dd/MM/yyyy');
  String dateLabel(String raw) {
    if (raw.trim().isEmpty) return '';
    final d = DateTime.tryParse(raw) ?? _tryParseFr(raw);
    return d == null ? raw.trim() : df.format(d);
  }

  final parts = <String>[
    if (dues.lodgeDuesPaid)
      'Cotisation Loge : ${_euros(dues.lodgeDues)} reçus'
          '${_dateSuffix(dateLabel(dues.lodgeDuesPaidDate))}.',
    if (dues.orderDuesPaid)
      'Cotisation Ordre (${lodge.obedienceAcronym}) : '
          '${_euros(dues.orderDues)} reçus'
          '${_dateSuffix(dateLabel(dues.orderDuesPaidDate))}.',
  ];

  final lines = <String>[
    '${_greeting(member)},',
    '',
    'Votre R∴L∴ ${lodge.name} a la joie de vous adresser votre Quitus de '
        'cotisation $year.',
    '',
    ...parts,
    '',
    'Si vous avez besoin d’informations complémentaires, vous pouvez nous '
        'en faire part.',
    '',
    'Recevez, ${_greeting(member)}, nos pensées de lumière.',
    ..._signOffLines(members, lodgeVmName),
  ];
  return lines.join('\n');
}

String _dateSuffix(String label) => label.isEmpty ? '' : ' le $label';

DateTime? _tryParseFr(String raw) {
  final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(3)!),
    int.parse(m.group(2)!),
    int.parse(m.group(1)!),
  );
}
