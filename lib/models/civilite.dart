// Civilité maçonnique (Frère / Sœur) d'un membre, visiteur ou dignitaire —
// pilote le choix entre les formes genrées des documents officiels
// (« Le Frère Orateur » / « La Sœur Secrétaire », « F∴Sec∴ » / « S∴Sec∴ »).
// Champ facultatif : les fiches existantes non renseignées utilisent le
// repli neutre ci-dessous plutôt qu'une civilité devinée.
const String kFrere = 'Frère';
const String kSoeur = 'Sœur';
const List<String> kCivilites = [kFrere, kSoeur];

/// « F∴ », « S∴ », ou « F∴/S∴ » si la civilité n'est pas renseignée.
String civiliteAbbrev(String civilite) {
  if (civilite == kSoeur) return 'S∴';
  if (civilite == kFrere) return 'F∴';
  return 'F∴/S∴';
}

/// « Le Frère », « La Sœur », ou « Le F∴/S∴ » si la civilité n'est pas
/// renseignée.
String civiliteTitle(String civilite) {
  if (civilite == kSoeur) return 'La Sœur';
  if (civilite == kFrere) return 'Le Frère';
  return 'Le F∴/S∴';
}

/// « le F∴ » / « la S∴ » (ou capitalisé « Le F∴ » / « La S∴ » en début de
/// phrase), repli « le F∴/S∴ » / « Le F∴/S∴ » si la civilité n'est pas
/// renseignée. Pour les phrases du corps du texte qui citent un visiteur ou
/// un dignitaire (par opposition à [civiliteTitle], utilisé pour les
/// libellés de signature en toutes lettres).
String civiliteArticleAbbrev(String civilite, {bool capitalize = false}) {
  final le = capitalize ? 'Le' : 'le';
  final la = capitalize ? 'La' : 'la';
  if (civilite == kSoeur) return '$la S∴';
  if (civilite == kFrere) return '$le F∴';
  return '$le F∴/S∴';
}
