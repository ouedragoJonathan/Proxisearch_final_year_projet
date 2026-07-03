import 'produit.dart';

class Categorie {
  Categorie({
    required this.id,
    required this.nom,
    required this.description,
    required this.iconeUrl,
    this.produits = const [],
  });

  final String id;
  final String nom;
  final String description;
  final String iconeUrl;
  final List<Produit> produits;

  int get productCount => produits.length;

  factory Categorie.fromJson(Map<String, dynamic> json) {
    final produitsJson = json['produits'];
    return Categorie(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconeUrl: json['icone_url']?.toString() ?? 'category',
      produits: produitsJson is List
          ? produitsJson
              .whereType<Map<String, dynamic>>()
              .map(Produit.fromJson)
              .toList()
          : const [],
    );
  }
}
