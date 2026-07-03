import 'categorie.dart';

class Stand {
  Stand({
    required this.id,
    required this.nomDuStand,
    required this.description,
    required this.position,
    this.positionX,
    this.positionY,
    this.positionVerrouillee = false,
    this.phoneMac,
    this.categories = const [],
  });

  final String id;
  final String nomDuStand;
  final String description;
  final String position;
  final double? positionX;
  final double? positionY;
  final bool positionVerrouillee;
  final String? phoneMac;
  final List<Categorie> categories;

  factory Stand.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'];
    return Stand(
      id: json['id']?.toString() ?? '',
      nomDuStand: json['nom_du_stand']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      positionX: (json['position_x'] as num?)?.toDouble(),
      positionY: (json['position_y'] as num?)?.toDouble(),
      positionVerrouillee: json['position_verrouillee'] == true,
      phoneMac: json['phone_mac']?.toString(),
      categories: categoriesJson is List
          ? categoriesJson
              .whereType<Map<String, dynamic>>()
              .map(Categorie.fromJson)
              .toList()
          : const [],
    );
  }
}
