import '../config/api_config.dart';
import '../models/categorie.dart';
import '../models/ibeacon.dart';
import '../models/produit.dart';
import '../models/promotion.dart';
import '../models/stand.dart';
import 'api_client.dart';

class MarketplaceService {
  MarketplaceService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Stand?> getMonStand() async {
    final response = await _client.get(ApiConfig.standsMonStand);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return Stand.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<Stand> creerStand({
    required String nomDuStand,
    required String description,
    required String position,
  }) async {
    final response = await _client.post(ApiConfig.standsCreation, {
      'nom_du_stand': nomDuStand,
      'description': description,
      'position': position,
    });
    if (response.statusCode != 201) {
      throw ApiException(_client.extractError(response));
    }
    return Stand.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<Stand> modifierStand({
    required String nomDuStand,
    required String description,
    required String position,
  }) async {
    final response = await _client.put(ApiConfig.standsModification, {
      'nom_du_stand': nomDuStand,
      'description': description,
      'position': position,
    });
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return Stand.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<void> supprimerStand() async {
    final response = await _client.delete(ApiConfig.standsSuppression);
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
  }

  Future<Stand> verrouillerPosition(String phoneMac) async {
    final response = await _client.post(ApiConfig.standsVerrouillerPosition, {
      'phone_mac': phoneMac,
    });
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return Stand.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<Categorie> creerCategorie({
    required String nom,
    required String description,
    required String iconeUrl,
  }) async {
    final response = await _client.post(ApiConfig.categoriesCreation, {
      'nom': nom,
      'description': description,
      'icone_url': iconeUrl,
    });
    if (response.statusCode != 201) {
      throw ApiException(_client.extractError(response));
    }
    return Categorie.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<Produit> creerProduit({
    required String nom,
    required String description,
    required int prix,
    required bool disponibilte,
    required String photoUrl,
    required String categorieId,
  }) async {
    final response = await _client.post(ApiConfig.produitsCreation, {
      'nom': nom,
      'description': description,
      'prix': prix,
      'disponibilte': disponibilte,
      'photo_url': photoUrl,
      'categorie_id': categorieId,
    });
    if (response.statusCode != 201) {
      throw ApiException(_client.extractError(response));
    }
    return Produit.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<Produit> modifierProduit({
    required String produitId,
    String? nom,
    String? description,
    int? prix,
    bool? disponibilte,
    String? photoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (nom != null) body['nom'] = nom;
    if (description != null) body['description'] = description;
    if (prix != null) body['prix'] = prix;
    if (disponibilte != null) body['disponibilte'] = disponibilte;
    if (photoUrl != null) body['photo_url'] = photoUrl;

    final response =
        await _client.put(ApiConfig.produitsModification(produitId), body);
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return Produit.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<void> supprimerProduit(String produitId) async {
    final response = await _client.delete(ApiConfig.produitsSuppression(produitId));
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
  }

  Future<List<Produit>> getProduitsParCategorie(String categorieId) async {
    final response =
        await _client.get(ApiConfig.produitsParCategorie(categorieId));
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final data = _client.decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Produit.fromJson)
        .toList();
  }

  Future<List<Produit>> rechercherProduits(String query) async {
    final response = await _client.get(
      ApiConfig.produitsRecherche,
      query: {'q': query},
      auth: false,
    );
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final data = _client.decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Produit.fromJson)
        .toList();
  }

  Future<Promotion> creerPromotion({
    required String titre,
    String? description,
    required List<String> produitsIds,
  }) async {
    final response = await _client.post(ApiConfig.promotionsCreation, {
      'titre': titre,
      'description': description,
      'produits_ids': produitsIds,
    });
    if (response.statusCode != 201) {
      throw ApiException(_client.extractError(response));
    }
    return Promotion.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<List<Promotion>> getMesPromotions() async {
    final response = await _client.get(ApiConfig.promotionsMes);
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    final data = _client.decodeJson(response);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Promotion.fromJson)
        .toList();
  }

  Future<IBeacon?> getMonIBeacon() async {
    final response = await _client.get(ApiConfig.ibeaconMon);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return IBeacon.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<IBeacon> creerIBeacon({
    required String uuid,
    required int major,
    required int minor,
    int rssiSeuil = -70,
    bool activite = true,
  }) async {
    final response = await _client.post(ApiConfig.ibeaconCreation, {
      'uuid': uuid,
      'major': major,
      'minor': minor,
      'rssi_seuil': rssiSeuil,
      'activite': activite,
    });
    if (response.statusCode != 201) {
      throw ApiException(_client.extractError(response));
    }
    return IBeacon.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<IBeacon> modifierIBeacon({
    required String id,
    String? uuid,
    int? major,
    int? minor,
    int? rssiSeuil,
    bool? activite,
  }) async {
    final body = <String, dynamic>{};
    if (uuid != null) body['uuid'] = uuid;
    if (major != null) body['major'] = major;
    if (minor != null) body['minor'] = minor;
    if (rssiSeuil != null) body['rssi_seuil'] = rssiSeuil;
    if (activite != null) body['activite'] = activite;

    final response = await _client.put(ApiConfig.ibeaconModification(id), body);
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response));
    }
    return IBeacon.fromJson(_client.decodeJson(response) as Map<String, dynamic>);
  }

  Future<void> supprimerIBeacon(String id) async {
    final response = await _client.delete(ApiConfig.ibeaconSuppression(id));
    if (response.statusCode != 204) {
      throw ApiException(_client.extractError(response));
    }
  }
}
