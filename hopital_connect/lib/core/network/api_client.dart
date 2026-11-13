import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../session/session_manager.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParameters,
    );
    return _send(() => _client.get(uri, headers: _headers()));
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) {
    return _send(
      () => _client.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(),
        body: jsonEncode(body ?? const <String, Object?>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, Object?> body,
  }) {
    return _send(
      () => _client.put(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = SessionManager.instance.token;
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() send,
  ) async {
    late final http.Response response;
    try {
      response = await send().timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw const ApiException(
        'Impossible de joindre le serveur. Vérifiez qu’il est démarré et que l’URL de l’API est correcte.',
      );
    } on TimeoutException {
      throw const ApiException('Le serveur met trop de temps à répondre.');
    }

    Map<String, dynamic> payload = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else {
        throw const ApiException('Réponse inattendue du serveur.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = payload['message'] ??
          (error is Map<String, dynamic> ? error['message'] : error);
      throw ApiException(
        message is String ? message : 'Erreur de communication avec le serveur.',
        statusCode: response.statusCode,
      );
    }
    return payload;
  }
}
