import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/vendeur.dart';

class VendeurException implements Exception {
  VendeurException(this.message);

  final String message;

  @override
  String toString() => message;
}

class VendeurService {
  VendeurService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 15);

  /// POST /vendeurs/inscription — crée un compte vendeur (VendeurCreate)
  Future<Vendeur> inscription(VendeurCreate donnees) async {
    final response = await _post(ApiConfig.vendeursInscription, donnees.toJson());

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Vendeur.fromJson(data);
    }

    throw VendeurException(_extractErrorMessage(response));
  }

  /// POST /vendeurs/connexion — authentifie un vendeur (VendeurLogin)
  Future<VendeurConnexionResponse> connexion(VendeurLogin donnees) async {
    final response = await _post(ApiConfig.vendeursConnexion, donnees.toJson());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return VendeurConnexionResponse.fromJson(data);
    }

    throw VendeurException(_extractErrorMessage(response));
  }

  Future<http.Response> _post(String url, Map<String, dynamic> body) async {
    try {
      return await _client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on SocketException {
      throw VendeurException(
        'Impossible de joindre l\'API ($url). '
        'Vérifiez que le Backend tourne et que le téléphone est sur le même Wi‑Fi '
        'que le PC (ipconfig → mettez à jour pcHostOverride dans api_config.dart).',
      );
    } on HttpException {
      throw VendeurException(
        'Erreur réseau vers $url. Vérifiez l\'IP du PC dans api_config.dart.',
      );
    } catch (e) {
      throw VendeurException(
        'Connexion à l\'API impossible ($url) : ${e.runtimeType}.',
      );
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
        }
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      return 'Numéro de téléphone ou mot de passe incorrect.';
    }
    if (response.statusCode == 409) {
      return 'Ce numéro de téléphone est déjà associé à un compte vendeur.';
    }

    return 'Erreur serveur (${response.statusCode}).';
  }
}
