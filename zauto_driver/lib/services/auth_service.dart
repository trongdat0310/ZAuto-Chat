import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';


class AuthService {
  static const String _tokenKey =
      'zauto_auth_token';

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();


  // ========================================
  // REGISTER
  // ========================================

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${AppConfig.backendUrl}/api/auth/register',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
      }),
    );

    return _handleAuthResponse(response);
  }


  // ========================================
  // LOGIN
  // ========================================

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${AppConfig.backendUrl}/api/auth/login',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    return _handleAuthResponse(response);
  }


  // ========================================
  // HANDLE LOGIN / REGISTER RESPONSE
  // ========================================

  Future<Map<String, dynamic>> _handleAuthResponse(
      http.Response response,
      ) async {
    final decoded =
    Map<String, dynamic>.from(
      jsonDecode(response.body),
    );

    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Xác thực thất bại',
      );
    }

    final token =
    decoded['token']?.toString();

    if (
    token == null ||
        token.isEmpty
    ) {
      throw Exception(
        'Backend không trả JWT token',
      );
    }

    await _storage.write(
      key: _tokenKey,
      value: token,
    );

    final user = decoded['user'];

    if (user is! Map) {
      throw Exception(
        'Thông tin người dùng không hợp lệ',
      );
    }

    return Map<String, dynamic>.from(
      user,
    );
  }


  // ========================================
  // GET TOKEN
  // ========================================

  Future<String?> getToken() {
    return _storage.read(
      key: _tokenKey,
    );
  }


  // ========================================
  // GET CURRENT USER
  // ========================================

  Future<Map<String, dynamic>?>
  getCurrentUser() async {
    final token =
    await getToken();

    if (
    token == null ||
        token.isEmpty
    ) {
      return null;
    }

    final response = await http.get(
      Uri.parse(
        '${AppConfig.backendUrl}/api/me',
      ),
      headers: {
        'Authorization':
        'Bearer $token',
      },
    );

    if (response.statusCode == 401) {
      await logout();
      return null;
    }

    final decoded =
    Map<String, dynamic>.from(
      jsonDecode(response.body),
    );

    if (decoded['success'] != true) {
      throw Exception(
        decoded['error'] ??
            'Không thể tải tài khoản',
      );
    }

    final user =
    decoded['user'];

    if (user is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(
      user,
    );
  }


  // ========================================
  // LOGOUT
  // ========================================

  Future<void> logout() async {
    final token =
    await getToken();

    try {
      if (
      token != null &&
          token.isNotEmpty
      ) {
        await http.post(
          Uri.parse(
            '${AppConfig.backendUrl}/api/auth/logout',
          ),
          headers: {
            'Authorization':
            'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Ke ca backend dang offline,
      // van logout local.
    } finally {
      await _storage.delete(
        key: _tokenKey,
      );
    }
  }

  // ========================================
  // AUTH HEADER
  // Sau nay groups / filters / zalo se dung
  // ========================================

  Future<Map<String, String>>
  authHeaders() async {
    final token =
    await getToken();

    if (token == null) {
      throw Exception(
        'Chưa đăng nhập',
      );
    }

    return {
      'Content-Type':
      'application/json',

      'Authorization':
      'Bearer $token',
    };
  }

  Future<void>
  clearLocalSession() async {

    await _storage.delete(
      key:
      _tokenKey,
    );
  }
}