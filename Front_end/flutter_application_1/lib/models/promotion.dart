class Promotion {
  Promotion({
    required this.id,
    required this.titre,
    this.description,
  });

  final String id;
  final String titre;
  final String? description;

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      titre: json['titre']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
