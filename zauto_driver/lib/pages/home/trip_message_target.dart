/// Identifies the source Zalo message shown on a Home trip card.
/// The trip's own `id` is an internal backend record ID, not a Zalo msgId.
class TripMessageTarget {
  const TripMessageTarget({
    required this.groupId,
    required this.groupName,
    this.msgId,
    this.cliMsgId,
  });

  final String groupId;
  final String groupName;
  final String? msgId;
  final String? cliMsgId;

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static TripMessageTarget? fromTrip(Map<String, dynamic> trip) {
    final groupId = _firstNonEmpty([
      trip['sourceThreadId'],
      trip['groupId'],
      trip['threadId'],
    ]);
    final msgId = _firstNonEmpty([
      trip['sourceMsgId'],
      trip['zaloMessageId'],
      trip['msgId'],
    ]);
    final cliMsgId = _firstNonEmpty([
      trip['sourceCliMsgId'],
      trip['clientMessageId'],
      trip['cliMsgId'],
    ]);

    // Never navigate to a guess: an internal trip ID is not a message ID.
    if (groupId == null || (msgId == null && cliMsgId == null)) {
      return null;
    }
    return TripMessageTarget(
      groupId: groupId,
      groupName: _firstNonEmpty([
            trip['groupName'],
            trip['sourceGroupName'],
          ]) ??
          'Nhóm Zalo',
      msgId: msgId,
      cliMsgId: cliMsgId,
    );
  }
}
