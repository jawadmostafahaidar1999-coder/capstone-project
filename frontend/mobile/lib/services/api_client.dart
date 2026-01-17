// lib/services/api_client.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  ApiException(this.statusCode, this.message, [this.data]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _client = http.Client();
  String? _token;

  static const String _webApiBaseUrl = 'http://localhost:8000/api';
  static const String _webPublicBaseUrl = 'http://localhost:8000';

  static const String _androidApiBaseUrl = 'http://10.0.2.2:8000/api';
  static const String _androidPublicBaseUrl = 'http://10.0.2.2:8000';

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String get baseUrl => _isAndroid ? _androidApiBaseUrl : _webApiBaseUrl;

  /// Public base URL (without /api) for images like /storage/...
  String get publicBaseUrl =>
      _isAndroid ? _androidPublicBaseUrl : _webPublicBaseUrl;

  bool get _logEnabled => kDebugMode;

  void _debugLog(String method, Uri uri, int? statusCode, String body) {
    if (!_logEnabled) return;

    final shortBody = body.length > 1200
        ? '${body.substring(0, 1200)}...<trimmed>'
        : body;

    // ignore: avoid_print
    print('[$method] $uri -> ${statusCode ?? '-'}\n$shortBody\n');
  }

  void setAuthToken(String? token) {
    _token = token;
  }

  Map<String, String> _jsonHeaders({bool auth = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Converts:
  /// - "/storage/..../x.jpg" => "http://localhost:8000/storage/..../x.jpg"
  /// - already full URL => unchanged
  /// - null/empty => null
  String? resolveImageUrl(String? path) {
    if (path == null) return null;
    final p = path.trim();
    if (p.isEmpty) return null;

    // already absolute
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    // common Laravel stored paths: "/storage/..."
    if (p.startsWith('/')) {
      return '$publicBaseUrl$p';
    }

    // fallback: "storage/..." (no leading slash)
    return '$publicBaseUrl/$p';
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));

    _debugLog('GET', uri, null, '');

    final response = await _client.get(uri, headers: _jsonHeaders(auth: auth));

    _debugLog('GET', uri, response.statusCode, response.body);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final payload = jsonEncode(body ?? {});

    _debugLog('POST', uri, null, payload);

    final response = await _client.post(
      uri,
      headers: _jsonHeaders(auth: auth),
      body: payload,
    );

    _debugLog('POST', uri, response.statusCode, response.body);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final payload = jsonEncode(body ?? {});

    _debugLog('PUT', uri, null, payload);

    final response = await _client.put(
      uri,
      headers: _jsonHeaders(auth: auth),
      body: payload,
    );

    _debugLog('PUT', uri, response.statusCode, response.body);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final payload = body != null ? jsonEncode(body) : '';

    _debugLog('DELETE', uri, null, payload);

    final response = await _client.delete(
      uri,
      headers: _jsonHeaders(auth: auth),
      body: body != null ? payload : null,
    );

    _debugLog('DELETE', uri, response.statusCode, response.body);

    return _decodeResponse(response);
  }

  /// Upload bytes as multipart/form-data
  Future<Map<String, dynamic>> uploadBytes(
    String path, {
    required Uint8List bytes,
    required String filename,
    bool auth = false,
    Map<String, String>? fields,
    String fileField = 'file',
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    _debugLog(
      'UPLOAD',
      uri,
      null,
      'multipart: $fileField=$filename, bytes=${bytes.length}, fields=${fields ?? {}}',
    );

    final req = http.MultipartRequest('POST', uri);
    req.headers['Accept'] = 'application/json';
    if (auth && _token != null) {
      req.headers['Authorization'] = 'Bearer $_token';
    }

    if (fields != null) req.fields.addAll(fields);

    req.files.add(
      http.MultipartFile.fromBytes(fileField, bytes, filename: filename),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    _debugLog('UPLOAD', uri, res.statusCode, res.body);

    return _decodeResponse(res);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final bodyText = response.body.isEmpty ? '{}' : response.body;

    dynamic decoded;
    try {
      decoded = jsonDecode(bodyText);
    } catch (_) {
      decoded = {'message': bodyText};
    }

    final Map<String, dynamic> json = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};

    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      return json;
    } else {
      final message =
          json['message']?.toString() ?? 'Request failed with status $status';
      throw ApiException(status, message, json);
    }
  }
}
