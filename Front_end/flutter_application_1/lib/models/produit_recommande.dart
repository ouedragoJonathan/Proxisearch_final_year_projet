class ProduitRecommande {
  ProduitRecommande({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.photoUrl,
    required this.nomStand,
    required this.nomCategorie,
    this.standId,
    this.positionX,
    this.positionY,
    this.positionVerrouillee = false,
  });

  final String id;
  final String nom;
  final String description;
  final int prix;
  final String photoUrl;
  final String nomStand;
  final String nomCategorie;
  final String? standId;
  final double? positionX;
  final double? positionY;
  final bool positionVerrouillee;

  bool get peutNaviguer =>
      positionVerrouillee &&
      standId != null &&
      standId!.isNotEmpty &&
      positionX != null &&
      positionY != null;

  factory ProduitRecommande.fromJson(Map<String, dynamic> json) {
    return ProduitRecommande(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      prix: (json['prix'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url']?.toString() ?? '',
      nomStand: json['nom_stand']?.toString() ?? '',
      nomCategorie: json['nom_categorie']?.toString() ?? '',
      standId: json['stand_id']?.toString(),
      positionX: (json['position_x'] as num?)?.toDouble(),
      positionY: (json['position_y'] as num?)?.toDouble(),
      positionVerrouillee: json['position_verrouillee'] == true,
    );
  }

  String get prixFormate {
    if (prix == prix.round()) {
      return '${prix.round()} FCFA';
    }
    return '${prix.toStringAsFixed(2).replaceAll('.', ',')} FCFA';
  }
}
