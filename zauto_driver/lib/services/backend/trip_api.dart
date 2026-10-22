import 'backend_api_base.dart';

class TripApi extends BackendApiBase {
  TripApi({required super.baseUrl, required super.auth});

  Future<Map<String, dynamic>> acceptMessage(String messageId, {String replyText = 'ok'}) async {
    // New authenticated route preserves structured quota/uncertain-send HTTP errors.
    final decoded = await postJson(Uri.parse(
      '$baseUrl/api/subscriptions/trips/${Uri.encodeComponent(messageId)}/accept'),
      body: {'replyText': replyText});
    return Map<String, dynamic>.from(decoded);
  }
  Future<Map<String, dynamic>> ignoreMessage(String messageId) async {
    final decoded = await postJson(Uri.parse('$baseUrl/api/me/messages/${Uri.encodeComponent(messageId)}/ignore'));
    return Map<String, dynamic>.from(decoded);
  }
  Future<List<Map<String, dynamic>>> getMessages({int limit = 100}) async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/messages?limit=$limit'));
    final raw = decoded['messages'];
    return raw is List ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList() : [];
  }
  Future<List<Map<String, dynamic>>> getRecentPendingTrips({required int displaySeconds, int limit = 200}) async {
    final decoded = await getJson(Uri.parse('$baseUrl/api/me/messages?limit=$limit'));
    final rawMessages = decoded['messages'];
    final serverNow = DateTime.tryParse(decoded['serverNow']?.toString() ?? '');
    if (rawMessages is! List || serverNow == null) return [];
    final result = <Map<String, dynamic>>[];
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final message = Map<String, dynamic>.from(raw);
      if (message['status'] != 'new') continue;
      final receivedAt = DateTime.tryParse(message['receivedAt']?.toString() ?? '');
      if (receivedAt == null) continue;
      final remaining = receivedAt.add(Duration(seconds: displaySeconds)).difference(serverNow).inMilliseconds;
      if (remaining <= 0) continue;
      result.add({...message, '_reconcileRemainingMs': remaining});
    }
    return result;
  }
  Future<List<Map<String, dynamic>>> getAcceptedTrips() async {
    // Includes chat accepts and successful sends whose trip-cache write was interrupted.
    final decoded = await getJson(Uri.parse('$baseUrl/api/subscriptions/me/history'));
    final raw = decoded['messages'];
    final result = raw is List
        ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    result.sort((a, b) => (DateTime.tryParse(b['acceptedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0))
      .compareTo(DateTime.tryParse(a['acceptedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return result;
  }
}
