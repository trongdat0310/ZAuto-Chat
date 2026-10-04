import 'backend_api_base.dart';

class NotificationFilterApi extends BackendApiBase {
  NotificationFilterApi({required super.baseUrl, required super.auth});

  Future<List<Map<String, dynamic>>> getFilters() async {
    final decoded = await getJson(
      Uri.parse('$baseUrl/api/me/notification-filters'),
    );

    final raw = decoded['filters'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createFilter(
    Map<String, dynamic> filter,
  ) async {
    final decoded = await postJson(
      Uri.parse('$baseUrl/api/me/notification-filters'),
      body: filter,
    );

    final raw = decoded['filter'];

    if (raw is! Map) {
      throw Exception('Dữ liệu bộ lọc không hợp lệ');
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> updateFilter(
    String filterId,
    Map<String, dynamic> filter,
  ) async {
    final decoded = await putJson(
      Uri.parse('$baseUrl/api/me/notification-filters/$filterId'),
      body: filter,
    );

    final raw = decoded['filter'];

    if (raw is! Map) {
      throw Exception('Dữ liệu bộ lọc không hợp lệ');
    }

    return Map<String, dynamic>.from(raw);
  }

  Future<void> deleteFilter(String filterId) async {
    await deleteJson(
      Uri.parse('$baseUrl/api/me/notification-filters/$filterId'),
    );
  }

  Future<Map<String, dynamic>> previewFilter({
    required Map<String, dynamic> filter,
    required String messageText,
    String? groupId,
  }) async {
    final decoded = await postJson(
      Uri.parse('$baseUrl/api/me/notification-filters/preview'),
      body: {
        'filter': filter,
        'messageText': messageText,
        if (groupId != null) 'groupId': groupId,
      },
    );

    final raw = decoded['result'];

    if (raw is! Map) {
      throw Exception('Kết quả kiểm tra không hợp lệ');
    }

    return Map<String, dynamic>.from(raw);
  }
}
