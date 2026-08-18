// Modèle d'un article de l'inventaire du matériel de Loge.

const String kInvPropGLDB = 'GLDB';
const String kInvPropLoge = 'Loge';
const String kInvPropFFSS = 'FF ou SS';

const List<String> kInventoryProperties = [
  kInvPropGLDB,
  kInvPropLoge,
  kInvPropFFSS,
];

class InventoryItem {
  final String id;
  final String category;
  final String name;
  final String quantity;
  final String property; // GLDB | Loge | FF ou SS
  final String? lentBy; // rempli seulement si property == FF ou SS
  final String? note;

  const InventoryItem({
    required this.id,
    this.category = '',
    this.name = '',
    this.quantity = '',
    this.property = kInvPropLoge,
    this.lentBy,
    this.note,
  });

  factory InventoryItem.fromMap(String id, Map<String, dynamic> map) {
    return InventoryItem(
      id: id,
      category: (map['category'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      quantity: (map['quantity'] ?? '') as String,
      property: (map['property'] ?? kInvPropLoge) as String,
      lentBy: map['lentBy'] as String?,
      note: map['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'category': category,
      'name': name,
      'quantity': quantity,
      'property': property,
      'lentBy': lentBy,
      'note': note,
    };
    map.removeWhere((key, value) => value == null);
    return map;
  }
}
