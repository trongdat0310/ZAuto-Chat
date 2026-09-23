import 'backend_api_base.dart';

class ConversationApi extends BackendApiBase {
  ConversationApi({required super.baseUrl, required super.auth});

  Future<List<Map<String, dynamic>>> getConversations() async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/conversations'));

    final raw = decoded['conversations'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> syncConversations() async {
    final decoded = await postJson(
      Uri.parse('$baseUrl/api/me/conversations/sync'),
    );

    return Map<String, dynamic>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> syncAndGetConversations() async {
    await syncConversations();
    return getConversations();
  }

  Future<Map<String, dynamic>> markConversationRead({
    required String groupId,
  }) async {
    final encodedGroupId = Uri.encodeComponent(groupId);

    final decoded = await postJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/read',
      ),
    );

    final raw = decoded['conversation'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  Future<Map<String, dynamic>> setConversationPinned({
    required String groupId,
    required bool pinned,
  }) async {
    final safeGroupId = groupId.trim();

    if (safeGroupId.isEmpty) {
      throw Exception('Group ID không hợp lệ');
    }

    final encodedGroupId = Uri.encodeComponent(safeGroupId);

    final decoded = await patchJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/pin',
      ),

      body: {'pinned': pinned},
    );

    final rawConversation = decoded['conversation'];

    return rawConversation is Map
        ? Map<String, dynamic>.from(rawConversation)
        : <String, dynamic>{};
  }

  Future<void> deleteConversation({required String groupId}) async {
    final safeGroupId = groupId.trim();

    if (safeGroupId.isEmpty) {
      throw Exception('Group ID không hợp lệ');
    }

    final encodedGroupId = Uri.encodeComponent(safeGroupId);

    await deleteJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId',
      ),
    );
  }
}
