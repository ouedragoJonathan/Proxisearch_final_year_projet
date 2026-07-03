class Produit {
  Produit({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.disponibilte,
    required this.photoUrl,
    required this.categorieId,
    this.promotions = const [],
  });

  final String id;
  final String nom;
  final String description;
  final int prix;
  final bool disponibilte;
  final String photoUrl;
  final String categorieId;
  final List<PromotionBrief> promotions;

  factory Produit.fromJson(Map<String, dynamic> json) {
    final promos = json['promotions'];
    return Produit(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      prix: (json['prix'] as num?)?.toInt() ?? 0,
      disponibilte: json['disponibilte'] == true,
      photoUrl: json['photo_url']?.toString() ?? '',
      categorieId: json['categorie_id']?.toString() ?? '',
      promotions: promos is List
          ? promos
              .whereType<Map<String, dynamic>>()
              .map(PromotionBrief.fromJson)
              .toList()
          : const [],
    );
  }

  static String formatPrix(int prix) {
    final amount = prix / 100;
    if (amount == amount.roundToDouble()) {
      return '${amount.round()} FCFA';
    }
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} FCFA';
  }

  static String prixToInput(int prix) {
    return (prix / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  static int? parsePrixFromInput(String input) {
    final cleaned = input
        .replaceAll('FCFA', '')
        .replaceAll('€', '')
        .trim()
        .replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }
}

class PromotionBrief {
  PromotionBrief({required this.id, required this.titre});

  final String id;
  final String titre;

  factory PromotionBrief.fromJson(Map<String, dynamic> json) {
    return PromotionBrief(
      id: json['id']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
    );
  }
}
