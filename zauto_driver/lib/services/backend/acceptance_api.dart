import 'backend_api_base.dart';

/// Receive actions are separate from ordinary chat send/reply operations.
class AcceptanceApi extends BackendApiBase {
  AcceptanceApi({required super.baseUrl, required super.auth});

  Future<Map<String, dynamic>> acceptChatMessage({
    required String groupId,
    required String replyText,
    String? msgId,
    String? cliMsgId,
  }) async {
    final decoded = await postJson(
      Uri.parse('$baseUrl/api/subscriptions/chat/accept'),
      body: {
        'groupId': groupId,
        'msgId': msgId,
        'cliMsgId': cliMsgId,
        'replyText': replyText,
      },
    );
    return Map<String, dynamic>.from(decoded as Map);
  }
}
