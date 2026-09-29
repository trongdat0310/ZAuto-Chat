import '../../services/backend_service.dart';

class ChatActionsController {
  final BackendService backend;

  final String groupId;

  bool sendingMessage = false;

  bool sendingPhoto = false;

  String? undoingMessageKey;

  String? deletingMessageKey;

  bool _disposed = false;

  ChatActionsController({required this.backend, required this.groupId});

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

    sendingMessage = true;

    try {
      await backend.sendConversationMessage(
        groupId: groupId,
        text: text,
        replyToMsgId: replyToMsgId,
        replyToCliMsgId: replyToCliMsgId,
      );

      if (_disposed) {
        return false;
      }

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

    sendingPhoto = true;

    try {
      await backend.sendConversationPhotos(
        groupId: groupId,
        filePaths: filePaths,
      );

      if (_disposed) {
        return false;
      }

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
