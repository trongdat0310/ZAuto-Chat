import 'backend_api_base.dart';

class MessageApi extends BackendApiBase {
  MessageApi({required super.baseUrl, required super.auth});

  Future<List<Map<String, dynamic>>> getConversationMessages({
    required String groupId,
    int limit = 100,
  }) async {
    final encodedGroupId = Uri.encodeComponent(groupId);

    final uri = Uri.parse(
      '$baseUrl/api/me/conversations/'
      '$encodedGroupId/messages',
    ).replace(queryParameters: {'limit': limit.toString()});

    final decoded = await getJson(uri);

    final raw = decoded['messages'];

    if (raw is! List) {
      return [];
    }

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getConversationMessagesPage({
    required String groupId,
    int limit = 50,
    String? beforeId,
    String? afterId,
  }) async {
    if (beforeId != null &&
        beforeId.isNotEmpty &&
        afterId != null &&
        afterId.isNotEmpty) {
      throw Exception('Chỉ được dùng beforeId hoặc afterId');
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    final query = <String, String>{'limit': limit.toString()};

    if (beforeId != null && beforeId.isNotEmpty) {
      query['beforeId'] = beforeId;
    }

    if (afterId != null && afterId.isNotEmpty) {
      query['afterId'] = afterId;
    }

    final uri = Uri.parse(
      '$baseUrl/api/me/conversations/'
      '$encodedGroupId/messages',
    ).replace(queryParameters: query);

    final decoded = await getJson(uri);

    final rawMessages = decoded['messages'];

    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];

    return {
      'messages': messages,

      'hasBefore': decoded['hasBefore'] == true,

      'hasAfter': decoded['hasAfter'] == true,

      'anchorFound': decoded['anchorFound'] != false,
    };
  }

  Future<Map<String, dynamic>> findConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {
    if ((msgId == null || msgId.isEmpty) &&
        (cliMsgId == null || cliMsgId.isEmpty)) {
      throw Exception('Cần msgId hoặc cliMsgId');
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    final query = <String, String>{};

    if (msgId != null && msgId.isNotEmpty) {
      query['msgId'] = msgId;
    }

    if (cliMsgId != null && cliMsgId.isNotEmpty) {
      query['cliMsgId'] = cliMsgId;
    }

    final uri = Uri.parse(
      '$baseUrl/api/me/conversations/'
      '$encodedGroupId/messages/target',
    ).replace(queryParameters: query);

    final decoded = await getJson(uri);

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> getConversationMessageContext({
    required String groupId,
    String? msgId,
    String? cliMsgId,
    int before = 60,
    int after = 60,
  }) async {
    final query = <String, String>{
      'before': before.toString(),

      'after': after.toString(),
    };

    if (msgId != null && msgId.isNotEmpty) {
      query['msgId'] = msgId;
    }

    if (cliMsgId != null && cliMsgId.isNotEmpty) {
      query['cliMsgId'] = cliMsgId;
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    final uri = Uri.parse(
      '$baseUrl/api/me/conversations/'
      '$encodedGroupId/messages/context',
    ).replace(queryParameters: query);

    final decoded = await getJson(uri);

    return Map<String, dynamic>.from(decoded);
  }

  Future<void> sendConversationMessage({
    required String groupId,
    required String text,

    String? replyToMsgId,
    String? replyToCliMsgId,
  }) async {
    final safeText = text.trim();

    if (safeText.isEmpty) {
      throw Exception('Nội dung tin nhắn đang trống');
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    final body = <String, dynamic>{'text': safeText};

    // ========================================
    // REPLY
    // ========================================

    final safeReplyMsgId = replyToMsgId?.trim();

    final safeReplyCliMsgId = replyToCliMsgId?.trim();

    if ((safeReplyMsgId != null && safeReplyMsgId.isNotEmpty) ||
        (safeReplyCliMsgId != null && safeReplyCliMsgId.isNotEmpty)) {
      body['replyTo'] = {
        'msgId': safeReplyMsgId,

        'cliMsgId': safeReplyCliMsgId,
      };
    }

    await postJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/messages/send',
      ),

      body: body,
    );
  }

  Future<void> undoConversationMessage({
    required String groupId,
    required String msgId,
    required String cliMsgId,
  }) async {
    final safeMsgId = msgId.trim();

    final safeCliMsgId = cliMsgId.trim();

    if (safeMsgId.isEmpty || safeCliMsgId.isEmpty) {
      throw Exception('Tin nhắn thiếu ID để thu hồi');
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    await postJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/messages/undo',
      ),

      body: {'msgId': safeMsgId, 'cliMsgId': safeCliMsgId},
    );
  }

  Future<void> deleteConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {
    final safeMsgId = msgId?.trim() ?? '';

    final safeCliMsgId = cliMsgId?.trim() ?? '';

    if (safeMsgId.isEmpty && safeCliMsgId.isEmpty) {
      throw Exception('Tin nhắn thiếu ID để xóa');
    }

    final encodedGroupId = Uri.encodeComponent(groupId);

    await postJson(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
        '$encodedGroupId/messages/delete',
      ),

      body: {
        'msgId': safeMsgId.isEmpty ? null : safeMsgId,

        'cliMsgId': safeCliMsgId.isEmpty ? null : safeCliMsgId,
      },
    );
  }
}
