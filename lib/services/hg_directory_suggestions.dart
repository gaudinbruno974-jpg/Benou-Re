// Suggestions (Loge / Obédience / Orient) pour les écrans Membres/Visiteurs/
// Dignitaires et le formulaire rapide de présence d'un corps de Hauts Grades
// (IAH-MES, MAA-Kherou) — demande explicite de l'utilisateur : les loges
// bleues ont des listes d'autocomplétion (DirectoryAutocompleteField), les
// corps de Hauts Grades n'en avaient pas. Toujours reconstruites à partir des
// 4 loges bleues (universe connu, voir kBlueLodgeDisplayName) ET des fiches
// déjà saisies dans le corps lui-même : toute nouvelle valeur tapée devient
// donc automatiquement une suggestion la prochaine fois, sans mécanisme de
// sauvegarde séparé.
import '../models/hg_body.dart';
import '../widgets/directory_filter.dart' show distinctSuggestions;
import 'grande_loge_directory_sync.dart'
    show kBlueLodgeDisplayName, kBlueLodgeObedience, kBlueLodgeOrient;
import 'hg_body_service.dart';

/// Valeur par défaut du champ Loge à la création d'une nouvelle fiche.
const String kHgDefaultLodgePrefix = 'R∴L∴ ';

class HgDirectorySuggestions {
  final List<String> lodges;
  final List<String> obediences;
  final List<String> orients;
  const HgDirectorySuggestions({
    required this.lodges,
    required this.obediences,
    required this.orients,
  });

  static const empty = HgDirectorySuggestions(
    lodges: [],
    obediences: [],
    orients: [],
  );
}

Future<HgDirectorySuggestions> loadHgDirectorySuggestions(HgBody body) async {
  final members = await HgBodyService.instance.membersOnce(body);
  final visitors = await HgBodyService.instance.visitorsOnce(body);
  final dignitaries = await HgBodyService.instance.dignitariesOnce(body);
  return HgDirectorySuggestions(
    lodges: distinctSuggestions([
      ...kBlueLodgeDisplayName.values,
      for (final m in members) m.motherLodge,
      for (final v in visitors) v.lodge,
      for (final d in dignitaries) d.lodge,
    ]),
    obediences: distinctSuggestions([
      kBlueLodgeObedience,
      for (final m in members) m.obedience,
      for (final v in visitors) v.obedience,
      for (final d in dignitaries) d.obedience,
    ]),
    orients: distinctSuggestions([
      kBlueLodgeOrient,
      for (final m in members) m.orient,
      for (final v in visitors) v.orient,
      for (final d in dignitaries) d.orient,
    ]),
  );
}
