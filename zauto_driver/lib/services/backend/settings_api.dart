import 'backend_api_base.dart';

class SettingsApi extends BackendApiBase {
  SettingsApi({required super.baseUrl, required super.auth});

  Future<Map<String, dynamic>> getFilters() async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/filters'));

    final filters = decoded['filters'];

    if (filters is! Map) {
      throw Exception('Dữ liệu bộ lọc không hợp lệ');
    }

    return Map<String, dynamic>.from(filters);
  }

  Future<Map<String, dynamic>> updateFilters({
    required List<String> includeKeywords,

    required List<String> excludeKeywords,

    required bool enabled,
  }) async {
    final decoded = await putJson(
      Uri.parse('$baseUrl/api/me/filters'),

      body: {
        'includeKeywords': includeKeywords,

        'excludeKeywords': excludeKeywords,

        'enabled': enabled,
      },
    );

    final filters = decoded['filters'];

    if (filters is! Map) {
      throw Exception('Dữ liệu bộ lọc không hợp lệ');
    }

    return Map<String, dynamic>.from(filters);
  }

  Future<Map<String, dynamic>> getMessageSettings() async {
    final decoded = await getJson(
      Uri.parse('$baseUrl/api/me/message-settings'),
    );

    final raw = decoded['settings'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateMessageSettings({
    bool? deduplicateMessages,

    int? dedupeWindowSeconds,
  }) async {
    final body = <String, dynamic>{};

    if (deduplicateMessages != null) {
      body['deduplicateMessages'] = deduplicateMessages;
    }

    if (dedupeWindowSeconds != null) {
      body['dedupeWindowSeconds'] = dedupeWindowSeconds;
    }

    final decoded = await patchJson(
      Uri.parse('$baseUrl/api/me/message-settings'),

      body: body,
    );

    final raw = decoded['settings'];

    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }
}
