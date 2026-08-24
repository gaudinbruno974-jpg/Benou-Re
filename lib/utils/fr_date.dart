// Parsing tolérant des dates saisies en texte libre sur les fiches (Date de
// naissance, d'initiation, d'entrée...) : « dd/MM/yyyy » en priorité (format
// du sélecteur de date de member_edit_screen.dart), repli sur ISO 8601 pour
// les valeurs importées d'ailleurs (xlsx, Firestore Timestamp déjà
// converti…). Renvoie `null` plutôt que de lever une exception sur une
// valeur vide ou mal formée — à l'appelant de décider quoi faire d'une date
// non reconnue (l'exclure d'un calcul, l'ignorer à l'affichage…).
DateTime? tryParseFrDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
  if (match != null) {
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }
  return DateTime.tryParse(trimmed);
}
