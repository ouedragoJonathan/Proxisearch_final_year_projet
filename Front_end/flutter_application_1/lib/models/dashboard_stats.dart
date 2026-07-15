class DashboardStats {
  DashboardStats({
    required this.nomStand,
    required this.clicsNotif,
    required this.produitsDisponibles,
    required this.totalProduits,
    required this.nombreCategories,
    required this.promotionsActives,
    required this.positionVerrouillee,
  });

  final String nomStand;
  final int clicsNotif;
  final int produitsDisponibles;
  final int totalProduits;
  final int nombreCategories;
  final int promotionsActives;
  final bool positionVerrouillee;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      nomStand: json['nom_stand']?.toString() ?? '',
      clicsNotif: (json['clics_notif'] as num?)?.toInt() ?? 0,
      produitsDisponibles: (json['produits_disponibles'] as num?)?.toInt() ?? 0,
      totalProduits: (json['total_produits'] as num?)?.toInt() ?? 0,
      nombreCategories: (json['nombre_categories'] as num?)?.toInt() ?? 0,
      promotionsActives: (json['promotions_actives'] as num?)?.toInt() ?? 0,
      positionVerrouillee: json['position_verrouillee'] == true,
    );
  }
}
