import 'promotion.dart';

class BeaconPromoResponse {
  BeaconPromoResponse({
    required this.nomStand,
    required this.promotions,
    this.message,
    this.vendeurId,
  });

  final String nomStand;
  final List<Promotion> promotions;
  final String? message;
  final String? vendeurId;

  bool get hasActivePromo => promotions.isNotEmpty;

  factory BeaconPromoResponse.fromJson(Map<String, dynamic> json) {
    final promosRaw = json['promotions'];
    return BeaconPromoResponse(
      nomStand: json['nom_stand']?.toString() ?? 'Stand partenaire',
      message: json['message']?.toString(),
      vendeurId: json['vendeur_id']?.toString(),
      promotions: promosRaw is List
          ? promosRaw
              .whereType<Map<String, dynamic>>()
              .map(Promotion.fromJson)
              .toList()
          : const [],
    );
  }
}
