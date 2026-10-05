import 'dart:async';

class ChatTargetController {
  static const int seekPageSize = 30;

  final String? targetMsgId;

  final String? targetCliMsgId;

  final String? targetReplyText;

  final int? targetAcceptedAtMs;

  int? targetIndex;

  String? targetErrorReason;

  bool highlightTarget = false;

  bool targetNoticeShown = false;

  bool seekingTarget = false;

  Timer? _highlightTimer;

  bool _disposed = false;

  ChatTargetController({
    required this.targetMsgId,
    required this.targetCliMsgId,
    this.targetReplyText,
    this.targetAcceptedAtMs,
  });

  // ========================================
  // CO TARGET TU LICH SU NHAN KHONG
  // ========================================

  bool get hasTarget {
    final safeTargetMsgId = targetMsgId?.trim() ?? '';

    final safeTargetCliMsgId = targetCliMsgId?.trim() ?? '';

    final safeReplyText =
        targetReplyText?.trim() ?? '';

    return safeTargetMsgId.isNotEmpty ||
        safeTargetCliMsgId.isNotEmpty ||
        (
          safeReplyText.isNotEmpty &&
          targetAcceptedAtMs != null
        );
  }

  // ========================================
  // RESET KHI LOAD LAI CHAT
  // ========================================

  void resetForLoad() {
    if (_disposed) {
      return;
    }

    cancelHighlightTimer();

    seekingTarget = false;

    targetIndex = null;

    highlightTarget = false;

    targetErrorReason = null;

    targetNoticeShown = false;
  }

  // ========================================
  // BAT DAU SEEK
  // ========================================

  void beginSeeking({bool clearCurrentTarget = false}) {
    if (_disposed) {
      return;
    }

    seekingTarget = true;

    if (clearCurrentTarget) {
      cancelHighlightTimer();

      targetIndex = null;

      highlightTarget = false;
    }
  }

  // ========================================
  // KET THUC SEEK
  // ========================================

  void finishSeeking() {
    if (_disposed) {
      return;
    }

    seekingTarget = false;
  }

  // ========================================
  // TARGET DA TIM THAY
  // ========================================

  void setFound(int index) {
    if (_disposed) {
      return;
    }

    targetIndex = index;

    targetErrorReason = null;
  }

  // ========================================
  // TARGET ERROR
  // ========================================

  void setError(String? reason) {
    if (_disposed) {
      return;
    }

    targetErrorReason = reason;
  }

  // ========================================
  // HIGHLIGHT
  // ========================================

  void showHighlight() {
    if (_disposed) {
      return;
    }

    highlightTarget = true;
  }

  void hideHighlight() {
    if (_disposed) {
      return;
    }

    highlightTarget = false;
  }

  void cancelHighlightTimer() {
    _highlightTimer?.cancel();

    _highlightTimer = null;
  }

  void scheduleHighlightRemoval({required void Function() onExpired}) {
    if (_disposed) {
      return;
    }

    cancelHighlightTimer();

    _highlightTimer = Timer(const Duration(seconds: 2), () {
      _highlightTimer = null;

      if (_disposed) {
        return;
      }

      highlightTarget = false;

      onExpired();
    });
  }

  // ========================================
  // MESSAGE BI XOA
  // ========================================

  void adjustAfterMessageRemoval(int removeIndex) {
    if (_disposed) {
      return;
    }

    final currentTarget = targetIndex;

    if (currentTarget == null) {
      return;
    }

    if (currentTarget == removeIndex) {
      cancelHighlightTimer();

      targetIndex = null;

      highlightTarget = false;

      return;
    }

    if (removeIndex < currentTarget) {
      targetIndex = currentTarget - 1;
    }
  }

  // ========================================
  // PREPEND HISTORY CU
  // ========================================

  void adjustAfterPrepend(int addedCount) {
    if (_disposed) {
      return;
    }

    if (addedCount <= 0 || targetIndex == null) {
      return;
    }

    targetIndex = targetIndex! + addedCount;
  }

  // ========================================
  // CLEAR TARGET HIEN TAI
  // ========================================

  void clearCurrentTarget() {
    if (_disposed) {
      return;
    }

    cancelHighlightTimer();

    targetIndex = null;

    highlightTarget = false;

    targetErrorReason = null;
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
    if (_disposed) {
      return false;
    }

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

    // ========================================
    // FALLBACK AN TOAN CHO LICH SU NHAN CU
    //
    // Chi tim tin do CHINH USER gui,
    // noi dung dung replyText va gan acceptedAt nhat.
    // Tuyet doi khong fallback sang tin cua khach.
    // ========================================

    final safeReplyText =
        targetReplyText?.trim() ?? '';

    final acceptedAtMs =
        targetAcceptedAtMs;


    if (
      safeReplyText.isEmpty ||
      acceptedAtMs == null
    ) {
      return -1;
    }


    const maxDistanceMs =
        Duration(minutes: 2)
            .inMilliseconds;

    var bestIndex =
        -1;

    int? bestDistance;


    for (
      var index = 0;
      index < messages.length;
      index += 1
    ) {
      final message =
          messages[index];


      if (
        message['isSelf'] !=
        true
      ) {
        continue;
      }


      final content =
          message['content']
              ?.toString()
              .trim() ??
          '';


      if (
        content !=
        safeReplyText
      ) {
        continue;
      }


      final timestamp =
          int.tryParse(
        message['timestamp']
                ?.toString() ??
            '',
      );


      if (
        timestamp == null
      ) {
        continue;
      }


      final distance =
          (timestamp -
                  acceptedAtMs)
              .abs();


      if (
        distance >
        maxDistanceMs
      ) {
        continue;
      }


      if (
        bestDistance == null ||
        distance <
            bestDistance
      ) {
        bestIndex =
            index;

        bestDistance =
            distance;
      }
    }


    return bestIndex;
  }

  // ========================================
  // DISPOSE
  // ========================================

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    cancelHighlightTimer();

    seekingTarget = false;

    highlightTarget = false;
  }
}
