// Suggestions (Loge / Obédience / Orient) pour les écrans Membres/Visiteurs/
// Dignitaires et le formulaire rapide de présence d'un corps de Hauts Grades
// (IAH-MES, MAA-Kherou) — demande explicite de l'utilisateur : les loges
// bleues ont des listes d'autocomplétion (DirectoryAutocompleteField), les
// corps de Hauts Grades n'en avaient pas. Toujours reconstruites à partir des
// 4 loges bleues (universe connu, voir kBlueLodgeDisplayName) ET des fiches
// déjà saisies dans le corps lui-même : toute nouvelle valeur tapée devient
// donc automatiquement une suggestion la prochaine fois, sans mécanisme de
// sauvegarde séparé.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/dignitary.dart';
import '../models/hg_body.dart';
import '../models/member.dart';
import '../models/visitor.dart';
import '../widgets/directory_filter.dart' show distinctSuggestions;
import 'grande_loge_directory_sync.dart'
    show kBlueLodgeDisplayName, kBlueLodgeObedience, kBlueLodgeOrient;

// Lecture forcée depuis le serveur (GetOptions(source: Source.server)) et non
// via HgBodyService.*Once (snapshots().first) : ce dernier peut résoudre
// depuis le cache local hors-ligne de Firestore avant que la réponse serveur
// n'arrive, proposant alors des valeurs fantômes déjà corrigées côté serveur
// mais encore présentes dans le cache du navigateur (constaté le 2026-10-22 :
// des variantes d'Orient disparues de la base depuis longtemps réapparaissant
// comme suggestions).
const _serverOnly = GetOptions(source: Source.server);

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
  final db = FirebaseFirestore.instance;
  final membersSnap = await db
      .collection(body.membersCollection)
      .get(_serverOnly);
  final visitorsSnap = await db
      .collection(body.visitorsCollection)
      .get(_serverOnly);
  final dignitariesSnap = await db
      .collection(body.dignitariesCollection)
      .get(_serverOnly);
  final members = [
    for (final doc in membersSnap.docs) Member.fromMap(doc.id, doc.data()),
  ];
  final visitors = [
    for (final doc in visitorsSnap.docs) Visitor.fromMap(doc.id, doc.data()),
  ];
  final dignitaries = [
    for (final doc in dignitariesSnap.docs)
      Dignitary.fromMap(doc.id, doc.data()),
  ];
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
