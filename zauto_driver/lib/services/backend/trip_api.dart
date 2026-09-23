import 'backend_api_base.dart';

class TripApi extends BackendApiBase {
  TripApi({required super.baseUrl, required super.auth});

  Future<Map<String, dynamic>> acceptMessage(
    String messageId, {

    String replyText = 'ok',
  }) async {
    final decoded = await postJson(
      Uri.parse(
        '$baseUrl/api/me/messages/'
        '$messageId/accept',
      ),

      body: {'replyText': replyText},
    );

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> ignoreMessage(String messageId) async {
    final decoded = await postJson(
      Uri.parse(
        '$baseUrl/api/me/messages/'
        '$messageId/ignore',
      ),
    );

    return Map<String, dynamic>.from(decoded);
  }

  Future<List<Map<String, dynamic>>> getMessages({int limit = 100}) async {
    final decoded = await getJson(
      Uri.parse(
        '$baseUrl/api/me/messages'
        '?limit=$limit',
      ),
    );

    final rawMessages = decoded['messages'];

    if (rawMessages is! List) {
      return [];
    }

    return rawMessages
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAcceptedTrips() async {
    final messages = await getMessages(limit: 500);

    final result = messages
        .where((message) => message['status'] == 'accepted')
        .map((message) => Map<String, dynamic>.from(message))
        .toList();

    result.sort((a, b) {
      final aTime =
          DateTime.tryParse(a['acceptedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bTime =
          DateTime.tryParse(b['acceptedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bTime.compareTo(aTime);
    });

    return result;
  }
}
