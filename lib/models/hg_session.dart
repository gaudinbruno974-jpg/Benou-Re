// Tenue d'un corps de Hauts Grades (IAH-MES, MAA-Kherou) — structure très
// différente d'une tenue de loge bleue (voir models/session.dart) : l'ordre
// du jour y est presque entièrement figé (voir hg_pdf_service.dart), seuls
// quelques champs varient d'une tenue à l'autre.
class HgSession {
  final String id;
  final String date; // ISO String
  final String heure; // « 19H30 »
  final int degree; // 4 à 14 pour IAH-MES
  final String lieu;
  final String themeTitle;
  final String themeText;
  final num agapePrice;

  /// Nom du signataire (« Trois Fois Puissant Maître » pour IAH-MES) — champ
  /// libre plutôt que déduit d'un compte : la personne qui tient ce rôle
  /// peut changer sans qu'on ait à retoucher le code.
  final String signerName;

  const HgSession({
    required this.id,
    this.date = '',
    this.heure = '19H30',
    this.degree = 4,
    this.lieu = '',
    this.themeTitle = '',
    this.themeText = '',
    this.agapePrice = 15,
    this.signerName = '',
  });

  factory HgSession.fromMap(String id, Map<String, dynamic> map) {
    return HgSession(
      id: id,
      date: (map['date'] ?? '') as String,
      heure: (map['heure'] ?? '19H30') as String,
      degree: ((map['degree'] ?? 4) as num).toInt(),
      lieu: (map['lieu'] ?? '') as String,
      themeTitle: (map['themeTitle'] ?? '') as String,
      themeText: (map['themeText'] ?? '') as String,
      agapePrice: (map['agapePrice'] ?? 15) as num,
      signerName: (map['signerName'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'heure': heure,
      'degree': degree,
      'lieu': lieu,
      'themeTitle': themeTitle,
      'themeText': themeText,
      'agapePrice': agapePrice,
      'signerName': signerName,
    };
  }

  DateTime? get dateTime => DateTime.tryParse(date);
}

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
