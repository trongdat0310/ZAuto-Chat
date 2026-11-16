import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/messages_refresh_plan.dart';

void main() {
  test('initial and reconnect refreshes still reconcile every resource', () {
    expect(MessagesRefreshPlan.forRealtimeEvent('authenticated'),
        MessagesRefreshPlan.all);
    expect(MessagesRefreshPlan.forRealtimeEvent('zalo_unlinked'),
        MessagesRefreshPlan.all);
    expect(MessagesRefreshPlan.forRealtimeEvent(null),
        MessagesRefreshPlan.all);
  });

  test('trip accepted refreshes history plus conversation preview', () {
    final plan = MessagesRefreshPlan.forRealtimeEvent('trip_accepted');
    expect(MessagesRefreshPlan.contains(plan, MessagesRefreshPlan.accepted), isTrue);
    expect(MessagesRefreshPlan.contains(plan, MessagesRefreshPlan.conversations), isTrue);
    expect(MessagesRefreshPlan.contains(plan, MessagesRefreshPlan.groups), isFalse);
  });

  test('group toggle and conversation edits avoid unrelated API requests', () {
    expect(MessagesRefreshPlan.forRealtimeEvent('group_notification_toggled'),
        MessagesRefreshPlan.groups);
    for (final event in [
      'conversation_read',
      'conversation_pinned',
      'conversation_deleted',
      'group_metadata_updated',
    ]) {
      expect(MessagesRefreshPlan.forRealtimeEvent(event),
          MessagesRefreshPlan.conversations);
    }
  });

  test('new messages preserve group discovery and chat reconciliation', () {
    for (final event in [
      'new_trip',
      'conversation_message',
      'conversation_message_updated',
      'conversation_history_synced',
    ]) {
      final sections = MessagesRefreshPlan.forRealtimeEvent(event);
      expect(sections, MessagesRefreshPlan.conversations | MessagesRefreshPlan.groups);
    }
  });

  test('coalescing multiple realtime invalidations retains each resource', () {
    final sections =
        MessagesRefreshPlan.forRealtimeEvent('conversation_message') |
        MessagesRefreshPlan.forRealtimeEvent('trip_accepted') |
        MessagesRefreshPlan.forRealtimeEvent('group_notification_toggled');
    expect(sections, MessagesRefreshPlan.all);
  });
}
