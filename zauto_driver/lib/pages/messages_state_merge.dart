/// Pure reconciliation of REST responses with pending local Messages actions.
///
/// A server response may arrive while the user is pinning or deleting a chat.
/// Keep the optimistic local state until its request finishes; neither this
/// helper nor the caller should mutate the server response objects.
abstract final class MessagesStateMerge {
  static List<Map<String, dynamic>> conversations(
    Iterable<Map<String, dynamic>> incoming, {
    required Iterable<Map<String, dynamic>> local,
    required Set<String> deletingGroupIds,
    required Map<String, bool> pendingPinValues,
  }) {
    final localById = <String, Map<String, dynamic>>{};
    for (final item in local) {
      final id = item['groupId']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      // Preserve the first match, just like the previous linear lookup.
      localById.putIfAbsent(id, () => item);
    }

    final result = <Map<String, dynamic>>[];
    for (final serverItem in incoming) {
      final copy = Map<String, dynamic>.from(serverItem);
      final id = copy['groupId']?.toString().trim();
      if (id == null || id.isEmpty) {
        result.add(copy);
        continue;
      }
      if (deletingGroupIds.contains(id)) continue;

      final pendingPin = pendingPinValues[id];
      if (pendingPin != null) {
        copy['pinned'] = pendingPin;
        final localConversation = localById[id];
        copy['pinnedAt'] = pendingPin
            ? (localConversation == null ? null : localConversation['pinnedAt'])
            : null;
      }
      result.add(copy);
    }
    return result;
  }

  static Set<String> enabledGroups(
    Iterable<Map<String, dynamic>> serverGroups, {
    required Map<String, bool> pendingNotificationValues,
  }) {
    final enabled = <String>{};
    for (final group in serverGroups) {
      if (group['enabled'] != true) continue;
      final id = group['groupId']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      enabled.add(id);
    }
    for (final entry in pendingNotificationValues.entries) {
      if (entry.value) {
        enabled.add(entry.key);
      } else {
        enabled.remove(entry.key);
      }
    }
    return enabled;
  }

  static void sortConversations(List<Map<String, dynamic>> conversations) {
    conversations.sort((a, b) {
      final aPinned = a['pinned'] == true;
      final bPinned = b['pinned'] == true;
      if (aPinned != bPinned) return aPinned ? -1 : 1;

      if (aPinned && bPinned) {
        final aPinnedAt = DateTime.tryParse(
          a['pinnedAt']?.toString() ?? '',
        )?.millisecondsSinceEpoch ?? 0;
        final bPinnedAt = DateTime.tryParse(
          b['pinnedAt']?.toString() ?? '',
        )?.millisecondsSinceEpoch ?? 0;
        if (aPinnedAt != bPinnedAt) {
          return bPinnedAt.compareTo(aPinnedAt);
        }
      }

      final aTime = int.tryParse(a['lastMessageAt']?.toString() ?? '') ?? 0;
      final bTime = int.tryParse(b['lastMessageAt']?.toString() ?? '') ?? 0;
      return bTime.compareTo(aTime);
    });
  }
}
