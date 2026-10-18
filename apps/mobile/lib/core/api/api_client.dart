import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String code;
  final String message;
  final List<dynamic>? details;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    this.details,
    required this.statusCode,
  });

  @override
  String toString() => '$code: $message';
}

class ApiClient {
  static const Duration requestTimeout = Duration(seconds: 5);

  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kReleaseMode) return 'https://dhurmit.onrender.com/api/v1';
    if (kIsWeb) return 'http://localhost:4000/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:4000/api/v1';
    return 'http://localhost:4000/api/v1';
  }

  final String baseUrl;
  final http.Client _client;
  String? authToken;
  String? workspaceId;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = httpClient ?? http.Client();

  Map<String, String> _buildHeaders({String? idempotencyKey}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    if (workspaceId != null && workspaceId!.isNotEmpty) {
      headers['X-Workspace-Id'] = workspaceId!;
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT',
        message: 'Network request timed out. Dhurmit is running in offline-first mode.',
        statusCode: 408,
      );
    } on SocketException {
      throw ApiException(
        code: 'OFFLINE',
        message: 'Network unreachable. Dhurmit is running in offline-first mode.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        code: 'CONNECTION_FAILED',
        message: e.message,
        statusCode: 503,
      );
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body, String? idempotencyKey}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(idempotencyKey: idempotencyKey),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT',
        message: 'Network request timed out. Dhurmit is running in offline-first mode.',
        statusCode: 408,
      );
    } on SocketException {
      throw ApiException(
        code: 'OFFLINE',
        message: 'Network unreachable. Changes have been queued in offline outbox.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        code: 'CONNECTION_FAILED',
        message: e.message,
        statusCode: 503,
      );
    }
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client
          .patch(
            uri,
            headers: _buildHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT',
        message: 'Network request timed out. Dhurmit is running in offline-first mode.',
        statusCode: 408,
      );
    } on SocketException {
      throw ApiException(
        code: 'OFFLINE',
        message: 'Network unreachable. Changes have been queued in offline outbox.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        code: 'CONNECTION_FAILED',
        message: e.message,
        statusCode: 503,
      );
    }
  }

  Future<dynamic> delete(String path, {String? idempotencyKey}) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _client
          .delete(
            uri,
            headers: _buildHeaders(idempotencyKey: idempotencyKey),
          )
          .timeout(requestTimeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT',
        message: 'Network request timed out. Dhurmit is running in offline-first mode.',
        statusCode: 408,
      );
    } on SocketException {
      throw ApiException(
        code: 'OFFLINE',
        message: 'Network unreachable. Dhurmit is running in offline-first mode.',
        statusCode: 503,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        code: 'CONNECTION_FAILED',
        message: e.message,
        statusCode: 503,
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>?;
      throw ApiException(
        code: (err?['code'] as String?) ?? 'UNKNOWN_ERROR',
        message: (err?['message'] as String?) ?? 'An error occurred',
        details: err?['details'] as List<dynamic>?,
        statusCode: response.statusCode,
      );
    }

    throw ApiException(
      code: 'HTTP_${response.statusCode}',
      message: 'Server returned HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}
