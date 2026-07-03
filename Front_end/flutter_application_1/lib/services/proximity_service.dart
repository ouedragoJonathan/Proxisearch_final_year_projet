import '../config/api_config.dart';
import '../models/beacon_promo_response.dart';
import 'api_client.dart';

class ProximityService {
  ProximityService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<BeaconPromoResponse?> detecterPromotions({
    required String uuid,
    required int major,
    required int minor,
  }) async {
    final response = await _client.get(
      ApiConfig.ibeaconDetecterPromotions(uuid, major, minor),
      auth: false,
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! Map<String, dynamic>) return null;
    return BeaconPromoResponse.fromJson(body);
  }
}
