import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth_service.dart';

class BackendApiBase {
  final String baseUrl;

  final AuthService auth;

  BackendApiBase({required this.baseUrl, required this.auth});

  Future<Map<String, String>> authHeaders() async {
    return auth.authHeaders();
  }

  Future<dynamic> getJson(Uri uri) async {
    final response = await http.get(uri, headers: await authHeaders());

    return _handleResponse(response);
  }

  Future<dynamic> postJson(Uri uri, {Object? body}) async {
    final response = await http.post(
      uri,

      headers: {...await authHeaders(), 'Content-Type': 'application/json'},

      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> patchJson(Uri uri, {Object? body}) async {
    final response = await http.patch(
      uri,

      headers: {...await authHeaders(), 'Content-Type': 'application/json'},

      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<dynamic> deleteJson(Uri uri, {Object? body}) async {
    final request = http.Request('DELETE', uri);

    request.headers.addAll(await authHeaders());

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';

      request.body = jsonEncode(body);
    }

    final streamed = await request.send();

    final response = await http.Response.fromStream(streamed);

    return _handleResponse(response);
  }

  Future<dynamic> putJson(Uri uri, {Object? body}) async {
    final response = await http.put(
      uri,

      headers: {...await authHeaders(), 'Content-Type': 'application/json'},

      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {};
      }

      throw Exception('Request thất bại');
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Phản hồi server không hợp lệ');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map
            ? (decoded['error'] ?? 'Request thất bại').toString()
            : 'Request thất bại',
      );
    }

    if (decoded is Map && decoded['success'] == false) {
      throw Exception(decoded['error'] ?? 'Request thất bại');
    }

    return decoded;
  }

  dynamic decodeMultipartResponse(http.Response response) {
    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map
            ? (decoded['error'] ?? 'Upload thất bại').toString()
            : 'Upload thất bại',
      );
    }

    if (decoded is Map && decoded['success'] == false) {
      throw Exception(decoded['error'] ?? 'Upload thất bại');
    }

    return decoded;
  }
}
