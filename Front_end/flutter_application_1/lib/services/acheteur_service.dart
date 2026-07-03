import '../config/api_config.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AcheteurService {
  AcheteurService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<String> loginOrRegister() async {
    final deviceUuid = await TokenStorage.getOrCreateDeviceUuid();
    final response = await _client.post(
      ApiConfig.acheteursAuth,
      {'device_uuid': deviceUuid},
      auth: false,
    );

    if (response.statusCode != 200) {
      throw ApiException(_client.extractError(response), statusCode: response.statusCode);
    }

    final body = _client.decodeJson(response);
    if (body is! Map<String, dynamic>) {
      throw ApiException('Réponse acheteur invalide.');
    }

    final acheteurId = body['acheteur_id']?.toString() ?? '';
    if (acheteurId.isEmpty) {
      throw ApiException('Identifiant acheteur manquant.');
    }

    await TokenStorage.saveAcheteurSession(
      acheteurId: acheteurId,
      deviceUuid: deviceUuid,
    );

    return acheteurId;
  }
}
