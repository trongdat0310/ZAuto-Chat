import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth_service.dart';

class BackendApiBase {
  static const Duration requestTimeout =
      Duration(seconds: 12);

  final String baseUrl;

  final AuthService auth;

  BackendApiBase({required this.baseUrl, required this.auth});

  Future<Map<String, String>> authHeaders() async {
    return auth.authHeaders();
  }

  Future<dynamic> getJson(Uri uri) async {
    final response = await _withNetworkHandling(
      http
          .get(
            uri,
            headers: await authHeaders(),
          )
          .timeout(requestTimeout),
    );

    return _handleResponse(response);
  }

  Future<dynamic> postJson(Uri uri, {Object? body}) async {
    final response = await _withNetworkHandling(
      http
          .post(
            uri,

            headers: {
              ...await authHeaders(),
              'Content-Type': 'application/json',
            },

            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout),
    );

    return _handleResponse(response);
  }

  Future<dynamic> patchJson(Uri uri, {Object? body}) async {
    final response = await _withNetworkHandling(
      http
          .patch(
            uri,

            headers: {
              ...await authHeaders(),
              'Content-Type': 'application/json',
            },

            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout),
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

    final streamed = await _withNetworkHandling(
      request
          .send()
          .timeout(requestTimeout),
    );

    final response = await _withNetworkHandling(
      http.Response
          .fromStream(streamed)
          .timeout(requestTimeout),
    );

    return _handleResponse(response);
  }

  Future<dynamic> putJson(Uri uri, {Object? body}) async {
    final response = await _withNetworkHandling(
      http
          .put(
            uri,

            headers: {
              ...await authHeaders(),
              'Content-Type': 'application/json',
            },

            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout),
    );

    return _handleResponse(response);
  }

  Future<T> _withNetworkHandling<T>(
    Future<T> request,
  ) async {
    try {
      return await request;
    } on TimeoutException {
      throw Exception(
        'Kết nối quá thời gian. Vui lòng kiểm tra mạng và thử lại.',
      );
    } on SocketException {
      throw Exception(
        'Không có kết nối mạng. Vui lòng kiểm tra mạng và thử lại.',
      );
    } on http.ClientException {
      throw Exception(
        'Không thể kết nối tới backend. Vui lòng thử lại.',
      );
    }
  }


  Future<dynamic> _handleResponse(http.Response response) async {
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

    if (response.statusCode == 401) {
      await auth.invalidateSession();

      throw Exception(
        decoded is Map
            ? (decoded['error'] ?? 'Phiên đăng nhập đã hết hạn.').toString()
            : 'Phiên đăng nhập đã hết hạn.',
      );
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
