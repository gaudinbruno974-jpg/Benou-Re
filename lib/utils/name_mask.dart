// Masquage des noms de personne dans les documents officiels (PDF), à la
// manière maçonnique : « Olivier » -> « Oli∴ », « PAYET » -> « PAY∴ ». Les
// mots (séparés par un espace ou un tiret) sont masqués indépendamment, ce
// qui couvre en un seul appel un prénom + nom complet
// (« Olivier PAYET » -> « Oli∴ PAY∴ »).
//
// N'est appliqué que dans `pdf_service.dart` (et à la génération des textes
// de convocation par défaut) : les getters `fullName` des modèles restent
// intacts, car l'application (listes de membres, écran de signature...) a
// besoin du nom réel.
final RegExp _nameSeparators = RegExp(r'[\s\-]+');

String maskPersonName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final buffer = StringBuffer();
  var lastEnd = 0;
  for (final match in _nameSeparators.allMatches(trimmed)) {
    buffer.write(_maskWord(trimmed.substring(lastEnd, match.start)));
    buffer.write(trimmed.substring(match.start, match.end));
    lastEnd = match.end;
  }
  buffer.write(_maskWord(trimmed.substring(lastEnd)));
  return buffer.toString();
}

String _maskWord(String word) {
  if (word.isEmpty) return word;
  final runes = word.runes.toList();
  final take = runes.length <= 3 ? runes.length : 3;
  return '${String.fromCharCodes(runes.take(take))}∴';
}
