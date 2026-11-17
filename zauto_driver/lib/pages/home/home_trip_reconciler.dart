/// Reconcile the latest server-side pending trips with Home's local state.
///
/// The backend determines which trips remain pending. Do not remove an
/// in-flight accept/ignore operation or a trip received after REST began.
/// This contains no network, audio, UI or notification side effects.
abstract final class HomeTripReconciler {
  static void apply({
    required List<Map<String, dynamic>> activeTrips,
    required Iterable<Map<String, dynamic>> pending,
    required int displaySeconds,
    required int reconcileStartedAtMs,
    required int nowMs,
  }) {
    final pendingById = <String, Map<String, dynamic>>{};
    for (final incoming in pending) {
      final id = incoming['id']?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      // Preserve existing behavior: the last pending entry wins on duplicate IDs.
      pendingById[id] = incoming;
    }

    activeTrips.removeWhere((trip) {
      final status = trip['_uiStatus']?.toString() ?? 'new';
      if (_isProtected(status)) return false;

      final addedAtMs = trip['_addedAtMs'];
      if (addedAtMs is int && addedAtMs > reconcileStartedAtMs) {
        return false;
      }

      final id = trip['id']?.toString().trim() ?? '';
      return id.isEmpty || !pendingById.containsKey(id);
    });

    for (final entry in pendingById.entries) {
      final id = entry.key;
      final incoming = entry.value;
      final remainingMs = incoming['_reconcileRemainingMs'];
      if (remainingMs is! int || remainingMs <= 0) continue;

      final existingIndex = activeTrips.indexWhere(
        (trip) => trip['id']?.toString() == id,
      );
      if (existingIndex >= 0) {
        final existing = activeTrips[existingIndex];
        final status = existing['_uiStatus']?.toString() ?? 'new';
        if (_isProtected(status)) continue;

        existing.addAll(incoming);
        _applyWindow(
          existing,
          remainingMs: remainingMs,
          nowMs: nowMs,
          displaySeconds: displaySeconds,
        );
        continue;
      }

      final restored = Map<String, dynamic>.from(incoming);
      restored['_addedAtMs'] = nowMs;
      _applyWindow(
        restored,
        remainingMs: remainingMs,
        nowMs: nowMs,
        displaySeconds: displaySeconds,
      );
      // Only add the restored card. No duplicate push, sound or notification.
      activeTrips.add(restored);
    }
  }

  static bool _isProtected(String status) =>
      status == 'accepting' ||
      status == 'ignoring' ||
      status == 'accepted' ||
      status == 'ignored';

  static void _applyWindow(
    Map<String, dynamic> trip, {
    required int remainingMs,
    required int nowMs,
    required int displaySeconds,
  }) {
    trip['_uiStatus'] = 'new';
    trip['_expiresAtMs'] = nowMs + remainingMs;
    trip['_pausedRemainingMs'] = null;
    trip['_remainingSeconds'] = ((remainingMs + 999) ~/ 1000)
        .clamp(0, displaySeconds)
        .toInt();
  }
}
