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
  test('hidden tab accumulates realtime scopes without consuming them', () {
    final queue = MessagesDeferredRefresh();
    queue.invalidate(MessagesRefreshPlan.conversations);
    queue.invalidate(MessagesRefreshPlan.groups);

    expect(queue.pendingSections,
        MessagesRefreshPlan.conversations | MessagesRefreshPlan.groups);
    expect(queue.takeWhenActive(false), 0);
    expect(queue.pendingSections,
        MessagesRefreshPlan.conversations | MessagesRefreshPlan.groups);

    // Activation merges a second event before the pending work is claimed.
    queue.invalidate(MessagesRefreshPlan.accepted);
    expect(queue.takeWhenActive(true), MessagesRefreshPlan.all);
    expect(queue.pendingSections, 0);
    expect(queue.takeWhenActive(true), 0);
  });

  test('deferred refresh masks unsupported bits and can clear on dispose', () {
    final queue = MessagesDeferredRefresh();
    queue.invalidate(128 | MessagesRefreshPlan.accepted);
    expect(queue.pendingSections, MessagesRefreshPlan.accepted);

    queue.clear();
    expect(queue.pendingSections, 0);
    queue.invalidate(MessagesRefreshPlan.all);
    expect(queue.takeWhenActive(true), MessagesRefreshPlan.all);
    expect(queue.pendingSections, 0);
  });

}
