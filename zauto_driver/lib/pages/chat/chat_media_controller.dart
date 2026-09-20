import 'dart:convert';

class ChatMediaController {
  // ========================================
  // PHOTO CONTENT
  // ========================================

  Map<String, dynamic>? extractPhotoContent(Map<String, dynamic> message) {
    final raw = message['rawData'];

    if (raw is! Map) {
      return null;
    }

    final rawMap = Map<String, dynamic>.from(raw);

    final content = rawMap['content'];

    if (content is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(content);
  }

  // ========================================
  // PHOTO URL
  // ========================================

  String? extractPhotoUrl(Map<String, dynamic> message) {
    final content = extractPhotoContent(message);

    if (content == null) {
      return null;
    }

    final href = content['href']?.toString().trim();

    if (href != null && href.isNotEmpty) {
      return href;
    }

    final thumb = content['thumb']?.toString().trim();

    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }

    return null;
  }

  // ========================================
  // PHOTO HERO TAG
  // ========================================

  String photoHeroTag(Map<String, dynamic> message) {
    final id = message['id']?.toString().trim();

    if (id != null && id.isNotEmpty) {
      return 'chat-photo-$id';
    }

    final msgId = message['msgId']?.toString().trim();

    if (msgId != null && msgId.isNotEmpty) {
      return 'chat-photo-$msgId';
    }

    final cliMsgId = message['cliMsgId']?.toString().trim();

    if (cliMsgId != null && cliMsgId.isNotEmpty) {
      return 'chat-photo-$cliMsgId';
    }

    return 'chat-photo-${identityHashCode(message)}';
  }

  // ========================================
  // PHOTO PARAMS
  // ========================================

  Map<String, dynamic> photoParams(Map<String, dynamic> message) {
    final raw = message['rawData'];

    if (raw is! Map) {
      return {};
    }

    final rawMap = Map<String, dynamic>.from(raw);

    final content = rawMap['content'];

    if (content is! Map) {
      return {};
    }

    final contentMap = Map<String, dynamic>.from(content);

    final params = contentMap['params'];

    if (params is Map) {
      return Map<String, dynamic>.from(params);
    }

    if (params is String && params.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(params);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // Ignore malformed params.
      }
    }

    return {};
  }

  // ========================================
  // MEDIA GROUP
  // ========================================

  String? mediaGroupId(Map<String, dynamic> message) {
    final direct = message['mediaGroupId']?.toString().trim();

    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final params = photoParams(message);

    final grouped =
        int.tryParse(
          (params['is_group_layout'] ?? params['isGroupLayout'] ?? 0)
              .toString(),
        ) ==
        1;

    if (!grouped) {
      return null;
    }

    final id = (params['group_layout_id'] ?? params['groupLayoutId'])
        ?.toString()
        .trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  int? mediaGroupIndex(Map<String, dynamic> message) {
    final direct = int.tryParse(message['mediaGroupIndex']?.toString() ?? '');

    if (direct != null) {
      return direct;
    }

    final params = photoParams(message);

    return int.tryParse(
      (params['id_in_group'] ?? params['idInGroup'] ?? '').toString(),
    );
  }

  // ========================================
  // MESSAGE TYPES
  // ========================================

  bool isPhotoMessage(Map<String, dynamic> message) {
    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return msgType == 'chat.photo' || msgType == '32';
  }

  bool isStickerMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'sticker' || msgType == 'chat.sticker';
  }

  bool isVideoMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'video' ||
        msgType == 'chat.video' ||
        msgType == 'chat.video.msg' ||
        msgType == '44';
  }

  bool isFileMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'file' ||
        msgType == 'share.file' ||
        msgType == 'chat.file' ||
        msgType == 'chat.file.msg' ||
        msgType == '46';
  }

  bool isVoiceMessage(Map<String, dynamic> message) {
    final mediaType =
        message['mediaType']?.toString().trim().toLowerCase() ?? '';

    final msgType = message['msgType']?.toString().trim().toLowerCase() ?? '';

    return mediaType == 'voice' ||
        msgType == 'chat.voice' ||
        msgType == 'chat.voice.msg' ||
        msgType == 'chat.audio' ||
        msgType == '31';
  }

  // ========================================
  // GENERIC MEDIA URL
  // ========================================

  String? messageMediaUrl(Map<String, dynamic> message) {
    final value = message['mediaUrl']?.toString().trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  String? messageMediaThumbUrl(Map<String, dynamic> message) {
    final value = message['mediaThumbUrl']?.toString().trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  // ========================================
  // PHOTO ALBUM
  // ========================================

  List<Map<String, dynamic>> albumMessagesFor(
    List<Map<String, dynamic>> messages,
    Map<String, dynamic> message,
  ) {
    final groupId = mediaGroupId(message);

    if (groupId == null) {
      return [message];
    }

    final result = messages.where((item) {
      if (item['status']?.toString() != 'normal') {
        return false;
      }

      return isPhotoMessage(item) && mediaGroupId(item) == groupId;
    }).toList();

    result.sort((a, b) {
      final aIndex = mediaGroupIndex(a) ?? 999999;

      final bIndex = mediaGroupIndex(b) ?? 999999;

      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }

      final aTime = int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;

      final bTime = int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;

      return aTime.compareTo(bTime);
    });

    return result;
  }

  int albumRenderIndex(
    List<Map<String, dynamic>> messages,
    String groupId, {
    int? targetIndex,
  }) {
    if (targetIndex != null &&
        targetIndex >= 0 &&
        targetIndex < messages.length &&
        mediaGroupId(messages[targetIndex]) == groupId) {
      return targetIndex;
    }

    int bestIndex = -1;

    int bestOrder = 999999;

    for (var index = 0; index < messages.length; index += 1) {
      final item = messages[index];

      if (item['status']?.toString() != 'normal' ||
          !isPhotoMessage(item) ||
          mediaGroupId(item) != groupId) {
        continue;
      }

      final order = mediaGroupIndex(item) ?? 999998;

      if (bestIndex < 0 || order < bestOrder) {
        bestIndex = index;

        bestOrder = order;
      }
    }

    return bestIndex;
  }

  // ========================================
  // ALL LOADED PHOTOS
  // ========================================

  List<Map<String, dynamic>> allLoadedPhotoMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final photos = messages.where((item) {
      final status = item['status']?.toString() ?? 'normal';

      if (status != 'normal') {
        return false;
      }

      if (!isPhotoMessage(item)) {
        return false;
      }

      final url = extractPhotoUrl(item);

      return url != null && url.isNotEmpty;
    }).toList();

    photos.sort((a, b) {
      final aTime = int.tryParse(a['timestamp']?.toString() ?? '') ?? 0;

      final bTime = int.tryParse(b['timestamp']?.toString() ?? '') ?? 0;

      if (aTime == bTime) {
        final aGroupIndex = mediaGroupIndex(a) ?? 0;

        final bGroupIndex = mediaGroupIndex(b) ?? 0;

        return aGroupIndex.compareTo(bGroupIndex);
      }

      return aTime.compareTo(bTime);
    });

    return photos;
  }
}
