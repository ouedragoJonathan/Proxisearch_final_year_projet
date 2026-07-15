import 'dart:io';

class ApiConfig {
  ApiConfig._();

  static const _port = 8000;
  static const String pcHostOverride = '192.168.11.106';

  static String get baseUrl {
    const customHost = String.fromEnvironment('API_HOST');
    if (customHost.isNotEmpty) {
      return 'http://$customHost:$_port';
    }
    if (pcHostOverride.isNotEmpty) {
      return 'http://$pcHostOverride:$_port';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:$_port';
    }
    return 'http://localhost:$_port';
  }

  static String get vendeursInscription => '$baseUrl/vendeurs/inscription';
  static String get vendeursConnexion => '$baseUrl/vendeurs/connexion';

  static String get standsMonStand => '$baseUrl/stands/mon-stand';
  static String get standsCreation => '$baseUrl/stands/creation';
  static String get standsModification => '$baseUrl/stands/modification';
  static String get standsSuppression => '$baseUrl/stands/suppression';
  static String get standsVerrouillerPosition =>
      '$baseUrl/stands/verrouiller-position';
  static String get standsDashboardStats => '$baseUrl/stands/dashboard-stats';

  static String get positionLatest => '$baseUrl/api/position/latest';
  static String get positionAll => '$baseUrl/api/position/all';
  static String get positionNavigation => '$baseUrl/api/position/navigation';

  static String get categoriesCreation => '$baseUrl/categories/creation';
  static String categorieModification(String id) =>
      '$baseUrl/categories/modification/$id';
  static String categorieSuppression(String id) =>
      '$baseUrl/categories/suppression/$id';

  static String produitsParCategorie(String id) =>
      '$baseUrl/produits/par-categorie/$id';
  static String get produitsCreation => '$baseUrl/produits/creation';
  static String produitsModification(String id) =>
      '$baseUrl/produits/modification/$id';
  static String produitsSuppression(String id) =>
      '$baseUrl/produits/suppression/$id';
  static String get produitsRecherche => '$baseUrl/produits/recherche';
  static String produitsRecommandations(String acheteurId) =>
      '$baseUrl/produits/recommandations?acheteur_id=$acheteurId';
  static String get produitsAleatoires => '$baseUrl/produits/aleatoires';

  static String get chatInterroger => '$baseUrl/chat/interroger';
  static String chatHistorique(String acheteurId) =>
      '$baseUrl/chat/historique/$acheteurId';
  static String chatEffacerHistorique(String acheteurId) =>
      '$baseUrl/chat/historique/$acheteurId';

  static String get acheteursAuth => '$baseUrl/acheteurs/auth';

  static String get promotionsCreation => '$baseUrl/promotions/creation';
  static String get promotionsMes => '$baseUrl/promotions/mes-promotions';
  static String promotionModification(String id) =>
      '$baseUrl/promotions/modification/$id';
  static String promotionSuppression(String id) =>
      '$baseUrl/promotions/suppression/$id';

  static String get ibeaconMon => '$baseUrl/ibeacons/mon-ibeacon';
  static String get ibeaconCreation => '$baseUrl/ibeacons/';
  static String ibeaconModification(String id) => '$baseUrl/ibeacons/$id';
  static String ibeaconSuppression(String id) => '$baseUrl/ibeacons/$id';
  static String ibeaconDetecterPromotions(String uuid, int major, int minor) =>
      '$baseUrl/ibeacons/detecter/promotions?uuid=$uuid&major=$major&minor=$minor';
}
