/// Which independent REST resources a Messages realtime event invalidates.
///
/// On login/reconnect and manual refresh, fetch all resources. Keep an event's
/// partial refresh limited to changed data, while pending events OR their
/// scopes together so a late event cannot overwrite an earlier refresh.
abstract final class MessagesRefreshPlan {
  static const int accepted = 1;
  static const int conversations = 2;
  static const int groups = 4;
  static const int all = accepted | conversations | groups;

  static bool contains(int scope, int section) => (scope & section) != 0;

  static int forRealtimeEvent(String? eventType) {
    switch (eventType) {
      case 'trip_accepted':
        // Sending an acceptance may also update the latest chat preview.
        return accepted | conversations;
      case 'group_notification_toggled':
        return groups;
      case 'conversation_read':
      case 'conversation_pinned':
      case 'conversation_deleted':
      case 'group_metadata_updated':
        return conversations;
      case 'conversation_message':
      case 'conversation_message_updated':
      case 'new_trip':
      case 'conversation_history_synced':
        // A newly observed group may also affect notification membership.
        return conversations | groups;
      default:
        // Auth, reconnect and unknown events retain full reconciliation.
        return all;
    }
  }
}

/// Coalesces realtime invalidations while Messages is hidden or debouncing.
/// A scoped refresh is claimed only when the tab is visible, so returning
/// to Messages cannot lose events that arrived while the tab was offstage.
class MessagesDeferredRefresh {
  int _pending = 0;

  int get pendingSections => _pending;

  void invalidate(int sections) {
    _pending |= sections & MessagesRefreshPlan.all;
  }

  int takeWhenActive(bool isActive) {
    if (!isActive) return 0;
    final sections = _pending;
    _pending = 0;
    return sections;
  }

  void clear() {
    _pending = 0;
  }
}
