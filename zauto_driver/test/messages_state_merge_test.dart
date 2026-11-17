import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/messages_state_merge.dart';

void main() {
  test('pending deletion prevents stale REST data from restoring a chat', () {
    final remote = <Map<String, dynamic>>[
      {'groupId': 'deleted', 'name': 'Old'},
      {'groupId': 'present', 'name': 'Still here'},
      {'name': 'Unknown group'},
    ];
    final merged = MessagesStateMerge.conversations(
      remote,
      local: const [],
      deletingGroupIds: {'deleted'},
      pendingPinValues: const {},
    );
    expect(merged.length, 2);
    expect(merged[0]['groupId'], 'present');
    expect(merged[1]['name'], 'Unknown group');
    expect(remote.length, 3);
  });

  test('optimistic pin keeps its local timestamp and does not mutate REST', () {
    final remote = <Map<String, dynamic>>[
      {'groupId': 'g1', 'pinned': false, 'pinnedAt': null},
    ];
    final local = <Map<String, dynamic>>[
      {'groupId': 'g1', 'pinned': true, 'pinnedAt': '2026-11-17T01:00:00Z'},
    ];
    final merged = MessagesStateMerge.conversations(
      remote,
      local: local,
      deletingGroupIds: const {},
      pendingPinValues: const {'g1': true},
    );
    expect(merged.single['pinned'], isTrue);
    expect(merged.single['pinnedAt'], '2026-11-17T01:00:00Z');
    expect(remote.single['pinned'], isFalse);
    expect(remote.single['pinnedAt'], isNull);
  });

  test('pending unpin clears timestamp and unrequested pins stay unchanged', () {
    final merged = MessagesStateMerge.conversations([
      {'groupId': 'g1', 'pinned': true, 'pinnedAt': 'server'},
      {'groupId': 'g2', 'pinned': true, 'pinnedAt': 'server'},
    ], local: const [], deletingGroupIds: const {},
        pendingPinValues: const {'g1': false});
    expect(merged[0]['pinned'], isFalse);
    expect(merged[0]['pinnedAt'], isNull);
    expect(merged[1]['pinned'], isTrue);
    expect(merged[1]['pinnedAt'], 'server');
  });

  test('server groups are merged with in-flight notification toggles', () {
    final enabled = MessagesStateMerge.enabledGroups([
      {'groupId': 'g1', 'enabled': true},
      {'groupId': 'g2', 'enabled': false},
      {'groupId': ' ', 'enabled': true},
    ], pendingNotificationValues: const {
      'g1': false,
      'g2': true,
      'g3': true,
    });
    expect(enabled, {'g2', 'g3'});

    final selected = <String>{'g1', 'g2'};
    selected.removeWhere((id) => !enabled.contains(id));
    expect(selected, {'g2'});
  });

  test('sorting prioritizes pinned, newest pin, then latest message', () {
    final rows = <Map<String, dynamic>>[
      {'groupId': 'a', 'pinned': false, 'lastMessageAt': 500},
      {'groupId': 'b', 'pinned': true,
        'pinnedAt': '2026-11-16T00:00:00Z', 'lastMessageAt': 5},
      {'groupId': 'c', 'pinned': true,
        'pinnedAt': '2026-11-17T00:00:00Z', 'lastMessageAt': 1},
      {'groupId': 'd', 'pinned': false, 'lastMessageAt': 800},
    ];
    MessagesStateMerge.sortConversations(rows);
    expect(rows.map((row) => row['groupId']), ['c', 'b', 'd', 'a']);
  });

  test('empty responses clear only the explicitly refreshed list', () {
    final merged = MessagesStateMerge.conversations(
      const [], local: const [], deletingGroupIds: const {},
      pendingPinValues: const {},
    );
    expect(merged, isEmpty);
    expect(MessagesStateMerge.enabledGroups(const [],
      pendingNotificationValues: const {}), isEmpty);
  });
}
