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

  Future<List<Map<String, dynamic>>> getMessages({
    int limit = 100,
    DateTime? from,
    DateTime? to,
    String? groupId,
    String? status,
    String? query,
  }) async {
    final parameters = <String, String>{
      'limit': limit.toString(),
    };

    if (from != null) {
      parameters['from'] = from.toUtc().toIso8601String();
    }

    if (to != null) {
      parameters['to'] = to.toUtc().toIso8601String();
    }

    final safeGroupId = groupId?.trim();

    if (safeGroupId != null && safeGroupId.isNotEmpty) {
      parameters['groupId'] = safeGroupId;
    }

    final safeStatus = status?.trim();

    if (safeStatus != null && safeStatus.isNotEmpty) {
      parameters['status'] = safeStatus;
    }

    final safeQuery = query?.trim();

    if (safeQuery != null && safeQuery.isNotEmpty) {
      parameters['q'] = safeQuery;
    }

    final uri = Uri.parse(
      '$baseUrl/api/me/messages',
    ).replace(queryParameters: parameters);

    final decoded = await getJson(uri);

    final rawMessages = decoded['messages'];

    if (rawMessages is! List) {
      return [];
    }

    return rawMessages
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getRecentPendingTrips({
    required int displaySeconds,
    int limit = 200,
  }) async {
    final decoded =
        await getJson(
      Uri.parse(
        '$baseUrl/api/me/messages'
        '?limit=$limit',
      ),
    );


    final rawMessages =
        decoded['messages'];

    final serverNow =
        DateTime.tryParse(
      decoded['serverNow']
              ?.toString() ??
          '',
    );


    if (
      rawMessages is! List ||
      serverNow == null
    ) {
      return [];
    }


    final result =
        <Map<String, dynamic>>[];


    for (
      final rawMessage
      in rawMessages
    ) {
      if (rawMessage is! Map) {
        continue;
      }


      final message =
          Map<String, dynamic>.from(
        rawMessage,
      );


      if (
        message['status'] !=
        'new'
      ) {
        continue;
      }


      final receivedAt =
          DateTime.tryParse(
        message['receivedAt']
                ?.toString() ??
            '',
      );


      if (
        receivedAt == null
      ) {
        continue;
      }


      final expiresAt =
          receivedAt.add(
        Duration(
          seconds:
              displaySeconds,
        ),
      );


      final remainingMs =
          expiresAt
              .difference(
                serverNow,
              )
              .inMilliseconds;


      if (
        remainingMs <=
        0
      ) {
        continue;
      }


      result.add(
        <String, dynamic>{
          ...message,

          '_reconcileRemainingMs':
              remainingMs,
        },
      );
    }


    return result;
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
