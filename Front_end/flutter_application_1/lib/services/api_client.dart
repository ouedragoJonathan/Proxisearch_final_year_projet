import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const defaultTimeout = Duration(seconds: 15);
  static const chatTimeout = Duration(seconds: 90);

  Future<Map<String, String>> authHeaders() async {
    final token = await TokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(
    String url, {
    Map<String, String>? query,
    bool auth = true,
    Duration timeout = defaultTimeout,
  }) async {
    final uri = Uri.parse(url).replace(queryParameters: query);
    try {
      return await _client
          .get(uri, headers: auth ? await authHeaders() : const {})
          .timeout(timeout);
    } on SocketException {
      throw ApiException('Impossible de joindre l\'API ($url).');
    }
  }

  Future<http.Response> post(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      return await _client
          .post(
            Uri.parse(url),
            headers: auth ? await authHeaders() : const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on SocketException {
      throw ApiException('Impossible de joindre l\'API ($url).');
    }
  }

  Future<http.Response> put(
    String url,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      return await _client
          .put(
            Uri.parse(url),
            headers: auth ? await authHeaders() : const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(defaultTimeout);
    } on SocketException {
      throw ApiException('Impossible de joindre l\'API ($url).');
    }
  }

  Future<http.Response> delete(String url, {bool auth = true}) async {
    try {
      return await _client
          .delete(Uri.parse(url), headers: auth ? await authHeaders() : const {})
          .timeout(defaultTimeout);
    } on SocketException {
      throw ApiException('Impossible de joindre l\'API ($url).');
    }
  }

  String extractError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List) {
          final messages = detail
              .whereType<Map<String, dynamic>>()
              .map((item) {
                final loc = item['loc'];
                final msg = item['msg']?.toString() ?? '';
                if (loc is List && loc.isNotEmpty) {
                  return '${loc.last}: $msg';
                }
                return msg;
              })
              .where((m) => m.isNotEmpty)
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
        }
      }
    } catch (_) {}
    return 'Erreur serveur (${response.statusCode}).';
  }

  dynamic decodeJson(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
