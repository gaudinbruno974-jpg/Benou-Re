// Un point d'ordre du jour complémentaire (au-delà des quatre travaux
// rituels fixes, voir session.dart) : soit un point libre classique, soit
// une planche avec un auteur identifié — pour permettre aux Statistiques et
// au Rapport pour la Grande Loge de compter les planches présentées par
// membre. Voir aussi Session.agendaItems (compatibilité avec les tenues
// déjà enregistrées, dont l'ordre du jour est un simple texte libre sans ce
// typage).
const String kAgendaItemSimple = 'simple';
const String kAgendaItemPlanche = 'planche';

class AgendaItem {
  /// Ligne telle qu'affichée/imprimée dans l'ordre du jour et la
  /// convocation — pour une planche, déjà composée automatiquement à partir
  /// de l'auteur et du titre (voir [agendaPlancheLine]), avec le nom tronqué
  /// à la manière maçonnique comme le reste des documents générés.
  final String text;

  /// [kAgendaItemSimple] / [kAgendaItemPlanche].
  final String type;

  /// Id du membre auteur — uniquement pour une planche. Sert à retrouver le
  /// membre réel (nom en clair) dans les écrans internes (Statistiques,
  /// Rapport), indépendamment du nom tronqué figé dans [text].
  final String authorId;

  /// Titre de la planche, facultatif.
  final String title;

  const AgendaItem({
    this.text = '',
    this.type = kAgendaItemSimple,
    this.authorId = '',
    this.title = '',
  });

  bool get isPlanche => type == kAgendaItemPlanche;

  factory AgendaItem.fromMap(Map<String, dynamic> map) {
    return AgendaItem(
      text: (map['text'] ?? '') as String,
      type: (map['type'] ?? kAgendaItemSimple) as String,
      authorId: (map['authorId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'text': text,
    'type': type,
    'authorId': authorId,
    'title': title,
  };
}

/// Compose la ligne d'ordre du jour d'une planche à partir de l'auteur (déjà
/// mis en forme — en clair ou tronqué selon l'appelant) et du titre
/// facultatif.
String agendaPlancheLine({required String authorDisplayName, String title = ''}) {
  final t = title.trim();
  if (t.isEmpty) return 'Planche présentée par $authorDisplayName';
  return 'Planche : « $t » — présentée par $authorDisplayName';
}
