import 'backend_api_base.dart';

class AccountApi extends BackendApiBase {
  AccountApi({required super.baseUrl, required super.auth});

  Future<Map<String, dynamic>> getProfile() async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/profile'));

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> unlinkZalo() async {
    await postJson(Uri.parse('$baseUrl/api/me/zalo/unlink'));
  }

  Future<Map<String, dynamic>> updateProfileName(String name) async {
    final decoded = await patchJson(
      Uri.parse('$baseUrl/api/me/profile'),

      body: {'name': name},
    );

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await postJson(
      Uri.parse('$baseUrl/api/me/change-password'),

      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> deleteAccount(String password) async {
    await deleteJson(
      Uri.parse('$baseUrl/api/me/account'),

      body: {'password': password},
    );
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await postJson(
      Uri.parse('$baseUrl/api/me/devices/register'),

      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDevice(String token) async {
    await postJson(
      Uri.parse('$baseUrl/api/me/devices/unregister'),

      body: {'token': token},
    );
  }
}
