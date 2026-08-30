import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';

class BackendService {

  final String baseUrl;

  final AuthService auth = AuthService();

  BackendService({
    required this.baseUrl,
  });

  WebSocketChannel? _channel;

  int _realtimeGeneration =
  0;

  bool _manualRealtimeDisconnect =
  false;

  String get _webSocketUrl {
    if (baseUrl.startsWith('https://')) {
      return '${baseUrl.replaceFirst('https://', 'wss://')}/ws';
    }

    return '${baseUrl.replaceFirst('http://', 'ws://')}/ws';
  }

  Stream<Map<String, dynamic>>
  connectRealtime() async* {

    // ========================================
    // MO MOT PHIEN REALTIME MOI
    //
    // Neu connectRealtime() duoc goi lai,
    // loop cu se tu dung.
    // ========================================

    final generation =
    ++_realtimeGeneration;


    _manualRealtimeDisconnect =
    false;


    // Dong socket cu neu co.
    try {

      await _channel
          ?.sink
          .close();

    } catch (_) {
      // Khong can lam gi.
    }


    while (
    !_manualRealtimeDisconnect &&
        generation ==
            _realtimeGeneration
    ) {
      int reconnectAttempt =
      0;

      WebSocketChannel?
      channel;


      try {
        reconnectAttempt +=
        1;


        debugPrint(
          'REALTIME CONNECT ATTEMPT '
              '#$reconnectAttempt',
        );

        // ========================================
        // DOC TOKEN MOI MOI LAN RECONNECT
        // ========================================

        final token =
        await auth
            .getToken();


        if (
        token == null ||
            token.isEmpty
        ) {

          throw Exception(
            'Chưa đăng nhập',
          );
        }


        debugPrint(
          'REALTIME CONNECTING...',
        );


        channel =
            WebSocketChannel
                .connect(
              Uri.parse(
                _webSocketUrl,
              ),
            );


        _channel =
            channel;


        // ========================================
        // DOI HANDSHAKE
        // ========================================

        await channel.ready.timeout(
          const Duration(
            seconds: 5,
          ),
        );


        if (
        _manualRealtimeDisconnect ||
            generation !=
                _realtimeGeneration
        ) {

          try {

            channel
                .sink
                .close();

          } catch (_) {
            // Ignore.
          }


          return;
        }


        debugPrint(
          'REALTIME CONNECTED',
        );

        reconnectAttempt =
        0;


        // ========================================
        // AUTH JWT
        // ========================================

        channel.sink.add(
          jsonEncode({
            'type':
            'auth',

            'token':
            token,
          }),
        );


        // ========================================
        // DOC EVENT CHO DEN KHI SOCKET BI DONG
        // ========================================

        await for (
        final rawEvent
        in channel.stream
        ) {

          if (
          _manualRealtimeDisconnect ||
              generation !=
                  _realtimeGeneration
          ) {

            return;
          }


          try {

            final decoded =
            jsonDecode(
              rawEvent
                  .toString(),
            );


            if (
            decoded is Map
            ) {

              yield Map<
                  String,
                  dynamic>.from(
                decoded,
              );
            }

          } catch (error) {

            debugPrint(
              'WebSocket decode error: '
                  '$error',
            );
          }
        }


        // ========================================
        // STREAM KET THUC
        //
        // VD:
        // - npm start bi tat
        // - backend restart
        // - mang bi mat
        //
        // KHONG RETURN.
        // XUONG DUOI DE RECONNECT.
        // ========================================

        debugPrint(
          'REALTIME DISCONNECTED',
        );

      } catch (error) {

        if (
        _manualRealtimeDisconnect ||
            generation !=
                _realtimeGeneration
        ) {

          return;
        }


        debugPrint(
          'REALTIME CONNECTION ERROR: '
              '$error',
        );


        debugPrint(
          'REALTIME WILL RETRY',
        );

      } finally {

        if (
        identical(
          _channel,
          channel,
        )
        ) {

          _channel =
          null;
        }


        // ========================================
        // KHONG await close O DAY.
        //
        // Neu handshake dang timeout,
        // await sink.close() co the lai bi treo
        // va chan vong reconnect.
        // ========================================

        try {

          channel
              ?.sink
              .close();

        } catch (_) {
          // Ignore.
        }
      }


      // ========================================
      // NEU USER TU DONG disconnect()
      // THI KHONG RECONNECT.
      // ========================================

      if (
      _manualRealtimeDisconnect ||
          generation !=
              _realtimeGeneration
      ) {

        return;
      }


      // ========================================
      // DOI 2 GIAY ROI KET NOI LAI
      //
      // Backend dang tat:
      // 2s sau thu lai.
      // ========================================

      debugPrint(
        'REALTIME RECONNECT IN 2s...',
      );


      await Future.delayed(
        const Duration(
          seconds:
          2,
        ),
      );
    }
  }

  Future<Map<String, dynamic>>
  acceptMessage(
      String messageId,
      ) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/messages/$messageId/accept',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'replyText':
        'Nhận',
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể nhận cuốc',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }

  void disconnect() {

    // ========================================
    // DAY LA USER / PAGE CHU DONG DONG SOCKET
    //
    // KHONG DUOC AUTO RECONNECT SAU DAY.
    // ========================================

    _manualRealtimeDisconnect =
    true;


    _realtimeGeneration +=
    1;


    final channel =
        _channel;


    _channel =
    null;


    try {

      channel
          ?.sink
          .close();

    } catch (_) {
      // Ignore.
    }
  }

  Future<List<Map<String, dynamic>>>
  getGroups() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/groups',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể tải danh sách nhóm',
      );
    }


    final rawGroups =
    decoded['groups'];


    if (
    rawGroups is! List
    ) {
      return [];
    }


    return rawGroups
        .map(
          (item) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .toList();
  }

  Future<bool> toggleGroup(
      String groupId,
      bool enabled,
      ) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/groups/$groupId/toggle',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'enabled':
        enabled,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể cập nhật nhóm',
      );
    }


    final group =
    decoded['group'];


    if (group is! Map) {
      return enabled;
    }


    return (
        group['enabled'] ==
            true
    );
  }

  Future<Map<String, dynamic>>
  getFilters() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/filters',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể tải bộ lọc',
      );
    }


    final filters =
    decoded['filters'];


    if (filters is! Map) {
      throw Exception(
        'Dữ liệu bộ lọc không hợp lệ',
      );
    }


    return Map<String, dynamic>.from(
      filters,
    );
  }

  Future<Map<String, dynamic>>
  updateFilters({
    required List<String>
    includeKeywords,

    required List<String>
    excludeKeywords,

    required bool enabled,
  }) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.put(
      Uri.parse(
        '$baseUrl/api/me/filters',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'includeKeywords':
        includeKeywords,

        'excludeKeywords':
        excludeKeywords,

        'enabled':
        enabled,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể lưu bộ lọc',
      );
    }


    final filters =
    decoded['filters'];


    if (filters is! Map) {
      throw Exception(
        'Dữ liệu bộ lọc không hợp lệ',
      );
    }


    return Map<String, dynamic>.from(
      filters,
    );
  }

  Future<List<Map<String, dynamic>>>
  getMessages({
    int limit = 100,
  }) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/messages?limit=$limit',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể tải lịch sử',
      );
    }


    final rawMessages =
    decoded['messages'];


    if (
    rawMessages is! List
    ) {
      return [];
    }


    return rawMessages
        .map(
          (item) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .toList();
  }


  Future<Map<String, dynamic>>
  ignoreMessage(
      String messageId,
      ) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/messages/$messageId/ignore',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể bỏ qua cuốc',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/devices/register',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'token':
        token,

        'platform':
        platform,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể đăng ký thiết bị',
      );
    }
  }

  Future<void> unregisterDevice(
      String token,
      ) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/devices/unregister',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'token':
        token,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể gỡ thiết bị',
      );
    }
  }

  Future<Map<String, dynamic>>
  getProfile() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/profile',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể tải thông tin tài khoản',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }


  // ========================================
  // UNLINK ZALO
  // ========================================

  Future<void> unlinkZalo() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/zalo/unlink',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể ngắt liên kết Zalo',
      );
    }
  }

  // ========================================
  // UPDATE ACCOUNT NAME
  // ========================================

  Future<Map<String, dynamic>>
  updateProfileName(
      String name,
      ) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.patch(
      Uri.parse(
        '$baseUrl/api/me/profile',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'name':
        name,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể cập nhật tên',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }


  // ========================================
  // CHANGE PASSWORD
  // ========================================

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/change-password',
      ),

      headers:
      headers,

      body:
      jsonEncode({
        'currentPassword':
        currentPassword,

        'newPassword':
        newPassword,
      }),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể đổi mật khẩu',
      );
    }
  }


  // ========================================
  // DELETE ACCOUNT
  // ========================================

  Future<void> deleteAccount(
      String password,
      ) async {

    final headers =
    await auth.authHeaders();


    final request =
    http.Request(
      'DELETE',

      Uri.parse(
        '$baseUrl/api/me/account',
      ),
    );


    request.headers
        .addAll(
      headers,
    );


    request.body =
        jsonEncode({
          'password':
          password,
        });


    final streamed =
    await request.send();


    final response =
    await http.Response
        .fromStream(
      streamed,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {
      throw Exception(
        decoded['error'] ??
            'Không thể xóa tài khoản',
      );
    }
  }

  // ========================================
  // GET ALL CONVERSATIONS
  // ========================================

  Future<List<Map<String, dynamic>>>
  getConversations() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/conversations',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể tải danh sách hội thoại',
      );
    }


    final raw =
    decoded['conversations'];


    if (raw is! List) {
      return [];
    }


    return raw
        .whereType<Map>()
        .map(
          (item) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .toList();
  }

  // ========================================
// MARK CONVERSATION AS READ
// ========================================

  Future<Map<String, dynamic>>
  markConversationRead({
    required String groupId,
  }) async {

    final safeGroupId =
    groupId.trim();


    if (
    safeGroupId.isEmpty
    ) {

      throw Exception(
        'Group ID không hợp lệ',
      );
    }


    final headers =
    await auth
        .authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      safeGroupId,
    );


    final response =
    await http.post(

      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/read',
      ),

      headers:
      headers,
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      throw Exception(
        'Phản hồi không hợp lệ từ server',
      );
    }


    if (
    response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(

        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể đánh dấu đã đọc'
        ).toString()
            : 'Không thể đánh dấu đã đọc',
      );
    }


    final rawConversation =
    decoded['conversation'];


    if (
    rawConversation is Map
    ) {

      return Map<String, dynamic>.from(
        rawConversation,
      );
    }


    return {};
  }

  // ========================================
  // GET CONVERSATION MESSAGES
  // ========================================

  Future<List<Map<String, dynamic>>>
  getConversationMessages({
    required String groupId,
    int limit = 100,
  }) async {

    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final uri =
    Uri.parse(
      '$baseUrl/api/me/conversations/'
          '$encodedGroupId/messages',
    ).replace(
      queryParameters: {
        'limit':
        limit.toString(),
      },
    );


    final response =
    await http.get(
      uri,

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể tải tin nhắn',
      );
    }


    final raw =
    decoded['messages'];


    if (raw is! List) {
      return [];
    }


    return raw
        .whereType<Map>()
        .map(
          (item) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .toList();
  }

  Future<Map<String, dynamic>>
  getConversationMessagesPage({
    required String groupId,
    int limit = 50,
    String? beforeId,
    String? afterId,
  }) async {

    if (
    beforeId != null &&
        beforeId.isNotEmpty &&
        afterId != null &&
        afterId.isNotEmpty
    ) {

      throw Exception(
        'Chỉ được dùng beforeId hoặc afterId',
      );
    }


    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final query =
    <String, String>{
      'limit':
      limit.toString(),
    };


    if (
    beforeId != null &&
        beforeId.isNotEmpty
    ) {

      query['beforeId'] =
          beforeId;
    }


    if (
    afterId != null &&
        afterId.isNotEmpty
    ) {

      query['afterId'] =
          afterId;
    }


    final uri =
    Uri.parse(
      '$baseUrl/api/me/conversations/'
          '$encodedGroupId/messages',
    ).replace(
      queryParameters:
      query,
    );


    final response =
    await http.get(
      uri,

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể tải tin nhắn',
      );
    }


    final rawMessages =
    decoded['messages'];


    final messages =
    rawMessages is List
        ? rawMessages
        .whereType<Map>()
        .map(
          (item) =>
      Map<String, dynamic>.from(
        item,
      ),
    )
        .toList()
        : <Map<String, dynamic>>[];


    return {
      'messages':
      messages,

      'hasBefore':
      decoded['hasBefore'] ==
          true,

      'hasAfter':
      decoded['hasAfter'] ==
          true,

      'anchorFound':
      decoded['anchorFound'] !=
          false,
    };
  }

  // ========================================
// FIND EXACT CONVERSATION MESSAGE
// ========================================

  Future<Map<String, dynamic>>
  findConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {

    if (
    (msgId == null ||
        msgId.isEmpty) &&
        (cliMsgId == null ||
            cliMsgId.isEmpty)
    ) {

      throw Exception(
        'Cần msgId hoặc cliMsgId',
      );
    }


    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final query =
    <String, String>{};


    if (
    msgId != null &&
        msgId.isNotEmpty
    ) {
      query['msgId'] =
          msgId;
    }


    if (
    cliMsgId != null &&
        cliMsgId.isNotEmpty
    ) {
      query['cliMsgId'] =
          cliMsgId;
    }


    final uri =
    Uri.parse(
      '$baseUrl/api/me/conversations/'
          '$encodedGroupId/messages/target',
    ).replace(
      queryParameters:
      query,
    );


    final response =
    await http.get(
      uri,

      headers:
      headers,
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      throw Exception(
        'Phản hồi không hợp lệ từ server',
      );
    }


    // ========================================
    // MESSAGE KHONG CON TON TAI
    // ========================================

    if (
    response.statusCode ==
        404
    ) {

      return {
        'success':
        false,

        'found':
        false,

        'reason':
        'not_found',

        'notice':
        decoded is Map
            ? decoded['error'] ??
            'Không tìm thấy tin nhắn'
            : 'Không tìm thấy tin nhắn',
      };
    }


    if (
    response.statusCode != 200
    ) {

      throw Exception(
        decoded is Map
            ? decoded['error'] ??
            'Không thể tìm tin nhắn'
            : 'Không thể tìm tin nhắn',
      );
    }


    if (decoded is! Map) {

      throw Exception(
        'Phản hồi không hợp lệ từ server',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ========================================
// SYNC CONVERSATIONS
// ========================================

  Future<Map<String, dynamic>>
  syncConversations() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/conversations/sync',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể đồng bộ hội thoại',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }

  // ========================================
// SYNC + RETURN CONVERSATIONS
// ========================================

  Future<List<Map<String, dynamic>>>
  syncAndGetConversations() async {

    await syncConversations();

    return getConversations();
  }

  Future<Map<String, dynamic>>
  getConversationMessageContext({
    required String groupId,
    String? msgId,
    String? cliMsgId,
    int before = 60,
    int after = 60,
  }) async {

    final headers =
    await auth.authHeaders();

    final query =
    <String, String>{
      'before':
      before.toString(),

      'after':
      after.toString(),
    };


    if (
    msgId != null &&
        msgId.isNotEmpty
    ) {
      query['msgId'] =
          msgId;
    }


    if (
    cliMsgId != null &&
        cliMsgId.isNotEmpty
    ) {
      query['cliMsgId'] =
          cliMsgId;
    }


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final uri =
    Uri.parse(
      '$baseUrl/api/me/conversations/'
          '$encodedGroupId/messages/context',
    ).replace(
      queryParameters:
      query,
    );


    final response =
    await http.get(
      uri,
      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể tìm tin nhắn',
      );
    }


    return Map<String, dynamic>.from(
      decoded,
    );
  }

  Future<List<Map<String, dynamic>>>
  getAcceptedTrips() async {

    final messages =
      await getMessages(
        limit:
        500,
      );


    final result =
    messages
        .where(
          (message) =>
      message['status'] ==
          'accepted',
    )
        .map(
          (message) =>
      Map<String, dynamic>.from(
        message,
      ),
    )
        .toList();


    result.sort(
          (a, b) {

        final aTime =
            DateTime.tryParse(
              a['acceptedAt']
                  ?.toString() ??
                  '',
            ) ??
                DateTime.fromMillisecondsSinceEpoch(
                  0,
                );


        final bTime =
            DateTime.tryParse(
              b['acceptedAt']
                  ?.toString() ??
                  '',
            ) ??
                DateTime.fromMillisecondsSinceEpoch(
                  0,
                );


        return bTime
            .compareTo(
          aTime,
        );
      },
    );


    return result;
  }

  Future<Map<String, dynamic>>
  getMessageSettings() async {

    final headers =
    await auth.authHeaders();


    final response =
    await http.get(
      Uri.parse(
        '$baseUrl/api/me/message-settings',
      ),

      headers:
      headers,
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể tải cài đặt tin nhắn',
      );
    }


    final raw =
    decoded['settings'];


    return raw is Map
        ? Map<String, dynamic>.from(
      raw,
    )
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>>
  updateMessageSettings({
    bool? deduplicateMessages,
    int? dedupeWindowSeconds,
  }) async {

    final headers =
    await auth.authHeaders();


    final body =
    <String, dynamic>{};


    if (
    deduplicateMessages != null
    ) {

      body['deduplicateMessages'] =
          deduplicateMessages;
    }


    if (
    dedupeWindowSeconds != null
    ) {

      body['dedupeWindowSeconds'] =
          dedupeWindowSeconds;
    }


    final response =
    await http.patch(
      Uri.parse(
        '$baseUrl/api/me/message-settings',
      ),

      headers: {
        ...headers,
        'Content-Type':
        'application/json',
      },

      body:
      jsonEncode(
        body,
      ),
    );


    final decoded =
    jsonDecode(
      response.body,
    );


    if (
    response.statusCode != 200 ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded['error'] ??
            'Không thể lưu cài đặt tin nhắn',
      );
    }


    final raw =
    decoded['settings'];


    return raw is Map
        ? Map<String, dynamic>.from(
      raw,
    )
        : <String, dynamic>{};
  }

  Future<void>
  sendConversationMessage({
    required String groupId,
    required String text,

    String? replyToMsgId,
    String? replyToCliMsgId,
  }) async {

    final safeText =
    text.trim();


    if (safeText.isEmpty) {

      throw Exception(
        'Nội dung tin nhắn đang trống',
      );
    }


    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final body =
    <String, dynamic>{
      'text':
      safeText,
    };


    // ========================================
    // REPLY
    // ========================================

    final safeReplyMsgId =
    replyToMsgId
        ?.trim();


    final safeReplyCliMsgId =
    replyToCliMsgId
        ?.trim();


    if (
    (
        safeReplyMsgId != null &&
            safeReplyMsgId.isNotEmpty
    ) ||
        (
            safeReplyCliMsgId != null &&
                safeReplyCliMsgId.isNotEmpty
        )
    ) {

      body['replyTo'] =
      {
        'msgId':
        safeReplyMsgId,

        'cliMsgId':
        safeReplyCliMsgId,
      };
    }


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/messages/send',
      ),

      headers: {
        ...headers,

        'Content-Type':
        'application/json',
      },

      body:
      jsonEncode(
        body,
      ),
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      decoded =
      null;
    }


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể gửi tin nhắn'
        )
            .toString()

            : 'Không thể gửi tin nhắn',
      );
    }
  }

  Future<void>
  sendConversationPhoto({
    required String groupId,
    required String filePath,
  }) async {

    final safeFilePath =
    filePath
        .trim();


    if (
    safeFilePath.isEmpty
    ) {

      throw Exception(
        'Không có ảnh để gửi',
      );
    }


    final headers =
    await auth
        .authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    // ========================================
    // MULTIPART REQUEST
    //
    // KHONG TU SET Content-Type.
    // MultipartRequest se tu tao boundary.
    // ========================================

    final request =
    http.MultipartRequest(
      'POST',

      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/messages/photo',
      ),
    );


    request.headers
        .addAll(
      headers,
    );


    request.files.add(
      await http.MultipartFile
          .fromPath(
        'photo',
        safeFilePath,
      ),
    );


    final streamedResponse =
    await request
        .send();


    final response =
    await http.Response
        .fromStream(
      streamedResponse,
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      decoded =
      null;
    }


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể gửi ảnh'
        ).toString()
            : 'Không thể gửi ảnh',
      );
    }
  }

  Future<void>
  sendConversationPhotos({
    required String groupId,
    required List<String> filePaths,
  }) async {

    final safePaths =
    filePaths
        .map(
          (
          path,
          ) =>
          path.trim(),
    )
        .where(
          (
          path,
          ) =>
      path.isNotEmpty,
    )
        .toList();


    if (
    safePaths.isEmpty
    ) {

      throw Exception(
        'Chưa chọn ảnh',
      );
    }


    if (
    safePaths.length >
        10
    ) {

      throw Exception(
        'Mỗi lần chỉ gửi tối đa 10 ảnh',
      );
    }


    final headers =
    await auth
        .authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final request =
    http.MultipartRequest(
      'POST',

      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/messages/photos',
      ),
    );


    request.headers
        .addAll(
      headers,
    );


    for (
    final path
    in safePaths
    ) {

      request.files.add(
        await http.MultipartFile
            .fromPath(
          'photos',
          path,
        ),
      );
    }


    final streamedResponse =
    await request
        .send();


    final response =
    await http.Response
        .fromStream(
      streamedResponse,
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      decoded =
      null;
    }


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể gửi ảnh'
        ).toString()
            : 'Không thể gửi ảnh',
      );
    }
  }

  Future<void>
  undoConversationMessage({
    required String groupId,
    required String msgId,
    required String cliMsgId,
  }) async {

    final safeMsgId =
    msgId.trim();


    final safeCliMsgId =
    cliMsgId.trim();


    if (
    safeMsgId.isEmpty ||
        safeCliMsgId.isEmpty
    ) {

      throw Exception(
        'Tin nhắn thiếu ID để thu hồi',
      );
    }


    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/messages/undo',
      ),

      headers: {
        ...headers,

        'Content-Type':
        'application/json',
      },

      body:
      jsonEncode({
        'msgId':
        safeMsgId,

        'cliMsgId':
        safeCliMsgId,
      }),
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      decoded =
      null;
    }


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể thu hồi tin nhắn'
        )
            .toString()

            : 'Không thể thu hồi tin nhắn',
      );
    }
  }

  Future<void>
  deleteConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {

    final safeMsgId =
        msgId
            ?.trim() ??
            '';


    final safeCliMsgId =
        cliMsgId
            ?.trim() ??
            '';


    if (
    safeMsgId.isEmpty &&
        safeCliMsgId.isEmpty
    ) {

      throw Exception(
        'Tin nhắn thiếu ID để xóa',
      );
    }


    final headers =
    await auth.authHeaders();


    final encodedGroupId =
    Uri.encodeComponent(
      groupId,
    );


    final response =
    await http.post(
      Uri.parse(
        '$baseUrl/api/me/conversations/'
            '$encodedGroupId/messages/delete',
      ),

      headers: {
        ...headers,

        'Content-Type':
        'application/json',
      },

      body:
      jsonEncode({
        'msgId':
        safeMsgId.isEmpty
            ? null
            : safeMsgId,

        'cliMsgId':
        safeCliMsgId.isEmpty
            ? null
            : safeCliMsgId,
      }),
    );


    dynamic decoded;


    try {

      decoded =
          jsonDecode(
            response.body,
          );

    } catch (_) {

      decoded =
      null;
    }


    if (
    response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map ||
        decoded['success'] != true
    ) {

      throw Exception(
        decoded is Map
            ? (
            decoded['error'] ??
                'Không thể xóa tin nhắn'
        )
            .toString()

            : 'Không thể xóa tin nhắn',
      );
    }
  }

}

