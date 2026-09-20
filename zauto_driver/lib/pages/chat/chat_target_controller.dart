import 'dart:async';

class ChatTargetController {
  static const int seekPageSize = 30;

  final String? targetMsgId;

  final String? targetCliMsgId;

  int? targetIndex;

  String? targetErrorReason;

  bool highlightTarget = false;

  bool targetNoticeShown = false;

  bool seekingTarget = false;

  Timer? _highlightTimer;

  ChatTargetController({
    required this.targetMsgId,
    required this.targetCliMsgId,
  });

  // ========================================
  // CO TARGET TU LICH SU NHAN KHONG
  // ========================================

  bool get hasTarget {
    final safeTargetMsgId = targetMsgId?.trim() ?? '';

    final safeTargetCliMsgId = targetCliMsgId?.trim() ?? '';

    return safeTargetMsgId.isNotEmpty || safeTargetCliMsgId.isNotEmpty;
  }

  // ========================================
  // RESET KHI LOAD LAI CHAT
  // ========================================

  void resetForLoad() {
    seekingTarget = false;

    targetIndex = null;

    highlightTarget = false;

    targetErrorReason = null;

    targetNoticeShown = false;

    cancelHighlightTimer();
  }

  // ========================================
  // BAT DAU SEEK
  // ========================================

  void beginSeeking({bool clearCurrentTarget = false}) {
    seekingTarget = true;

    if (clearCurrentTarget) {
      targetIndex = null;

      highlightTarget = false;
    }
  }

  // ========================================
  // KET THUC SEEK
  // ========================================

  void finishSeeking() {
    seekingTarget = false;
  }

  // ========================================
  // TARGET DA TIM THAY
  // ========================================

  void setFound(int index) {
    targetIndex = index;

    targetErrorReason = null;
  }

  // ========================================
  // TARGET ERROR
  // ========================================

  void setError(String? reason) {
    targetErrorReason = reason;
  }

  // ========================================
  // HIGHLIGHT
  // ========================================

  void showHighlight() {
    highlightTarget = true;
  }

  void hideHighlight() {
    highlightTarget = false;
  }

  void cancelHighlightTimer() {
    _highlightTimer?.cancel();

    _highlightTimer = null;
  }

  void scheduleHighlightRemoval({required void Function() onExpired}) {
    cancelHighlightTimer();

    _highlightTimer = Timer(const Duration(seconds: 2), () {
      _highlightTimer = null;

      highlightTarget = false;

      onExpired();
    });
  }

  // ========================================
  // MESSAGE BI XOA
  // ========================================

  void adjustAfterMessageRemoval(int removeIndex) {
    final currentTarget = targetIndex;

    if (currentTarget == null) {
      return;
    }

    // ========================================
    // XOA DUNG TARGET
    // ========================================

    if (currentTarget == removeIndex) {
      targetIndex = null;

      highlightTarget = false;

      return;
    }

    // ========================================
    // XOA MESSAGE NAM TRUOC TARGET
    // -> INDEX TARGET GIAM 1
    // ========================================

    if (removeIndex < currentTarget) {
      targetIndex = currentTarget - 1;
    }
  }

  // ========================================
  // PREPEND HISTORY CU
  // ========================================

  void adjustAfterPrepend(int addedCount) {
    if (addedCount <= 0 || targetIndex == null) {
      return;
    }

    targetIndex = targetIndex! + addedCount;
  }

  // ========================================
  // CLEAR TARGET HIEN TAI
  // ========================================

  void clearCurrentTarget() {
    targetIndex = null;

    highlightTarget = false;

    targetErrorReason = null;

    cancelHighlightTimer();
  }

  // ========================================
  // TIM MESSAGE BANG ID BAT KY
  //
  // DUNG CHO QUOTE NAVIGATION.
  // KHAC VOI findTargetIndex()
  // VI DAY KHONG PHAI TARGET TU CONSTRUCTOR.
  // ========================================

  int findMessageIndexByIds(
    List<Map<String, dynamic>> messages, {
    String? msgId,
    String? cliMsgId,
  }) {
    final safeMsgId = msgId?.trim() ?? '';

    final safeCliMsgId = cliMsgId?.trim() ?? '';

    return messages.indexWhere((message) {
      final messageMsgId = message['msgId']?.toString().trim() ?? '';

      final messageCliMsgId = message['cliMsgId']?.toString().trim() ?? '';

      final sameMsgId =
          safeMsgId.isNotEmpty &&
          messageMsgId.isNotEmpty &&
          safeMsgId == messageMsgId;

      final sameCliMsgId =
          safeCliMsgId.isNotEmpty &&
          messageCliMsgId.isNotEmpty &&
          safeCliMsgId == messageCliMsgId;

      return sameMsgId || sameCliMsgId;
    });
  }

  // ========================================
  // NOTICE KHONG TIM THAY
  // ========================================

  bool markNoticeShown() {
    if (targetNoticeShown) {
      return false;
    }

    targetNoticeShown = true;

    return true;
  }

  // ========================================
  // TIM TARGET TRONG MESSAGE DA LOAD
  //
  // NEU CO msgId -> CHI TIM msgId.
  // CHI FALLBACK cliMsgId NEU KHONG CO msgId.
  // ========================================

  int findTargetIndex(List<Map<String, dynamic>> messages) {
    final safeTargetMsgId = targetMsgId?.trim() ?? '';

    final safeTargetCliMsgId = targetCliMsgId?.trim() ?? '';

    if (safeTargetMsgId.isNotEmpty) {
      return messages.indexWhere((message) {
        final messageMsgId = message['msgId']?.toString().trim() ?? '';

        return messageMsgId.isNotEmpty && messageMsgId == safeTargetMsgId;
      });
    }

    if (safeTargetCliMsgId.isNotEmpty) {
      return messages.indexWhere((message) {
        final messageCliMsgId = message['cliMsgId']?.toString().trim() ?? '';

        return messageCliMsgId.isNotEmpty &&
            messageCliMsgId == safeTargetCliMsgId;
      });
    }

    return -1;
  }

  // ========================================
  // DISPOSE
  // ========================================

  void dispose() {
    cancelHighlightTimer();
  }
}
