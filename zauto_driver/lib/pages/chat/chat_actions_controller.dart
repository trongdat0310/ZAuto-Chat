import 'dart:math';

import '../../services/backend_service.dart';

class ChatActionsController {
  final BackendService backend;

  final String groupId;

  bool sendingMessage = false;

  bool sendingPhoto = false;

  String? undoingMessageKey;

  String? deletingMessageKey;

  bool _disposed = false;

  final Random _random = Random.secure();

  String? _textRetrySignature;

  String? _textRetryRequestId;

  String? _photoRetrySignature;

  String? _photoRetryRequestId;

  ChatActionsController({required this.backend, required this.groupId});

  String _newRequestId(String kind) {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);

    final random = List<String>.generate(
      4,
      (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();

    return '$kind-$now-$random';
  }

  String _textSignature({
    required String text,
    String? replyToMsgId,
    String? replyToCliMsgId,
  }) {
    return [
      text,
      replyToMsgId ?? '',
      replyToCliMsgId ?? '',
    ].join('\u001f');
  }

  String _photoSignature(List<String> filePaths) {
    return filePaths.join('\u001f');
  }

  // ========================================
  // MESSAGE ACTION KEY
  // ========================================

  String messageActionKey(Map<String, dynamic> message) {
    return message['id']?.toString() ??
        message['msgId']?.toString() ??
        message['cliMsgId']?.toString() ??
        '';
  }

  // ========================================
  // GUI TEXT MESSAGE
  // ========================================

  Future<bool> sendText({
    required String text,
    String? replyToMsgId,
    String? replyToCliMsgId,
  }) async {
    if (_disposed || sendingMessage || sendingPhoto) {
      return false;
    }

    final signature = _textSignature(
      text: text,
      replyToMsgId: replyToMsgId,
      replyToCliMsgId: replyToCliMsgId,
    );

    if (_textRetrySignature != signature || _textRetryRequestId == null) {
      _textRetrySignature = signature;

      _textRetryRequestId = _newRequestId('text');
    }

    final requestId = _textRetryRequestId!;

    sendingMessage = true;

    try {
      await backend.sendConversationMessage(
        groupId: groupId,
        text: text,
        clientRequestId: requestId,
        replyToMsgId: replyToMsgId,
        replyToCliMsgId: replyToCliMsgId,
      );

      if (_disposed) {
        return false;
      }

      _textRetrySignature = null;

      _textRetryRequestId = null;

      return true;
    } finally {
      sendingMessage = false;
    }
  }

  // ========================================
  // GUI PHOTO
  // ========================================

  Future<bool> sendPhotos({required List<String> filePaths}) async {
    if (_disposed || sendingPhoto || sendingMessage) {
      return false;
    }

    final signature = _photoSignature(filePaths);

    if (_photoRetrySignature != signature || _photoRetryRequestId == null) {
      _photoRetrySignature = signature;

      _photoRetryRequestId = _newRequestId('photo');
    }

    final requestId = _photoRetryRequestId!;

    sendingPhoto = true;

    try {
      await backend.sendConversationPhotos(
        groupId: groupId,
        filePaths: filePaths,
        clientRequestId: requestId,
      );

      if (_disposed) {
        return false;
      }

      _photoRetrySignature = null;

      _photoRetryRequestId = null;

      return true;
    } finally {
      sendingPhoto = false;
    }
  }

  // ========================================
  // DELETE LOCAL MESSAGE
  // ========================================

  Future<bool> deleteMessage({
    required String actionKey,
    String? msgId,
    String? cliMsgId,
  }) async {
    if (_disposed || actionKey.isEmpty || deletingMessageKey != null) {
      return false;
    }

    deletingMessageKey = actionKey;

    try {
      await backend.deleteConversationMessage(
        groupId: groupId,
        msgId: msgId,
        cliMsgId: cliMsgId,
      );

      if (_disposed) {
        return false;
      }

      return true;
    } finally {
      deletingMessageKey = null;
    }
  }

  // ========================================
  // RECALL MESSAGE
  // ========================================

  Future<bool> undoMessage({
    required String actionKey,
    required String msgId,
    required String cliMsgId,
  }) async {
    if (_disposed || actionKey.isEmpty || undoingMessageKey != null) {
      return false;
    }

    undoingMessageKey = actionKey;

    try {
      await backend.undoConversationMessage(
        groupId: groupId,
        msgId: msgId,
        cliMsgId: cliMsgId,
      );

      if (_disposed) {
        return false;
      }

      return true;
    } finally {
      undoingMessageKey = null;
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
  }
}
