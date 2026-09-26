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

/// Identifiants des dossiers Drive des rituels d'IAH-MES, par degré (4-14) —
/// même principe que LodgeConfig.libraryFolders des loges bleues : la tuile du
/// grade ouvre directement le dossier. Un degré absent garde « À venir ».
/// Liste affichée par « Créer l'arborescence Drive » (SSTR / IAH-MES /
/// Rituels 4-14).
const Map<int, String> kIahMesRituelsFolderIds = {
  4: '1MxOL37EM0qmDDiV57yFaUERkklGB4aSH', // 4° Maître Secret
  5: '1q8hzPsJS6GlHy5hBWdwbEh2f4FgRcRHH', // 5° Maître Parfait
  6: '1-QHIBZVLvrAmTMSn5SxazlWcpmJjYw60', // 6° Secrétaire Intime
  7: '11wIcFmsiAQZe5l9U8inIJ1oD8vHSoeq-', // 7° Prévôt et Juge
  8: '1B31WMt0B7FxrKzxqH3Smaeg6FrgW5Su_', // 8° Intendant des Bâtiments
  9: '1MZsUAug18UQSTY3dbcL4j1Z6zhm3_4mf', // 9° Maître Élu des Neuf
  10: '1rJUDQaDwN3kblKqjJf00kGGobHyPq9HU', // 10° Illustre Élu des Quinze
  11: '1E7F_Mf1eBi9pwuLNHXAABRnKlEEGCKBj', // 11° Sublime Chevalier Élu
  12: '15pgRnHX-hA037xHuZNCHL27mmOo88cn_', // 12° Grand Maître Architecte
  13: '1na0FnEUkbWIZ3-Erxy7aMkTU37JEVAWC', // 13° Royale Arche
  14: '1P9tykXBqPip0PJRotlA9LCeu7jCFv3L_', // 14° Grand Écossais de la Voûte Sacrée
};
