import 'dart:convert';

import 'package:http/http.dart'
as http;

import '../config/app_config.dart';
import 'auth_service.dart';


class ZaloLinkService {
  final AuthService auth =
  AuthService();


  Future<Map<String, dynamic>>
  start() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '${AppConfig.backendUrl}/api/zalo/link/start',
      ),
      headers: headers,
    );


    return _handle(
      response,
    );
  }


  Future<Map<String, dynamic>>
  status() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '${AppConfig.backendUrl}/api/zalo/link/status',
      ),
      headers: headers,
    );


    return _handle(
      response,
    );
  }


  Future<void> cancel() async {
    final headers =
    await auth.authHeaders();


    await http.post(
      Uri.parse(
        '${AppConfig.backendUrl}/api/zalo/link/cancel',
      ),
      headers: headers,
    );
  }


  Map<String, dynamic> _handle(
      http.Response response,
      ) {

    final decoded =
    Map<String, dynamic>.from(
      jsonDecode(
        response.body,
      ),
    );


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể liên kết Zalo',
      );
    }


    final link =
    decoded['link'];


    if (link is! Map) {
      return {};
    }


    return Map<String, dynamic>.from(
      link,
    );
  }
}