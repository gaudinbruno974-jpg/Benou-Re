// Nomenclature des degrés d'un corps de Hauts Grades (IAH-MES) — les tenues
// elles-mêmes réutilisent le modèle Session des loges bleues (voir
// hg_body_service.dart, demande explicite de l'utilisateur : « copie
// l'intégralité »), seul le champ degree/degreTravail y prend une valeur
// numérique « 4 » à « 14 » au lieu d'Apprenti/Compagnon/Maître.

/// Nomenclature standard du Collège de Perfection (4°-14°), reprise par la
/// plupart des rites dont Memphis-Misraïm — confirmée par l'utilisateur pour
/// IAH-MES.
const Map<int, String> kIahMesDegreeNames = {
  4: 'Maître Secret',
  5: 'Maître Parfait',
  6: 'Secrétaire Intime',
  7: 'Prévôt et Juge',
  8: 'Intendant des Bâtiments',
  9: 'Maître Élu des Neuf',
  10: 'Illustre Élu des Quinze',
  11: 'Sublime Chevalier Élu',
  12: 'Grand Maître Architecte',
  13: 'Royale Arche',
  14: 'Grand Écossais de la Voûte Sacrée',
};
