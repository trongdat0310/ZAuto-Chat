/// Countdown calculations for the Home trip screen.
///
/// The server remains authoritative about accepted/ignored trips. These
/// methods only manage the temporary UI display window. Passing [nowMs]
/// explicitly makes time boundaries deterministic in tests.
abstract final class HomeTripCountdown {
  static bool hasCountdownTrips(Iterable<Map<String, dynamic>> trips) {
    return trips.any(
      (trip) => (trip['_uiStatus']?.toString() ?? 'new') == 'new',
    );
  }

  static int remainingSeconds(
    Map<String, dynamic> trip, {
    required int displaySeconds,
    required int nowMs,
  }) {
    final pausedMs = trip['_pausedRemainingMs'];
    if (pausedMs is int) {
      return ((pausedMs + 999) ~/ 1000)
          .clamp(0, displaySeconds)
          .toInt();
    }

    final expiresAtMs = trip['_expiresAtMs'];
    if (expiresAtMs is! int) {
      return trip['_remainingSeconds'] is int
          ? trip['_remainingSeconds'] as int
          : displaySeconds;
    }

    final remainingMs = expiresAtMs - nowMs;
    if (remainingMs <= 0) return 0;
    return ((remainingMs + 999) ~/ 1000)
        .clamp(0, displaySeconds)
        .toInt();
  }

  static void pause(
    Map<String, dynamic> trip, {
    required int displaySeconds,
    required int nowMs,
  }) {
    final expiresAtMs = trip['_expiresAtMs'];
    if (expiresAtMs is int) {
      final remainingMs = expiresAtMs - nowMs;
      trip['_pausedRemainingMs'] = remainingMs > 0 ? remainingMs : 0;
    } else {
      final remainingSeconds = trip['_remainingSeconds'] is int
          ? trip['_remainingSeconds'] as int
          : displaySeconds;
      trip['_pausedRemainingMs'] = remainingSeconds * 1000;
    }
    trip['_expiresAtMs'] = null;
  }

  static void resume(
    Map<String, dynamic> trip, {
    required int displaySeconds,
    required int nowMs,
  }) {
    final pausedMs = trip['_pausedRemainingMs'];
    final remainingMs = pausedMs is int
        ? pausedMs
        : displaySeconds * 1000;
    trip['_pausedRemainingMs'] = null;
    trip['_expiresAtMs'] = nowMs + remainingMs;
    trip['_remainingSeconds'] = ((remainingMs + 999) ~/ 1000)
        .clamp(0, displaySeconds)
        .toInt();
  }

  /// Mutate display counters only; the caller removes expired trips inside
  /// setState() to avoid rebuilding Home on an ordinary one-second tick.
  static HomeTripTickResult tick(
    List<Map<String, dynamic>> trips, {
    required int displaySeconds,
    required int nowMs,
  }) {
    var changed = false;
    final expired = <Map<String, dynamic>>[];

    for (final trip in trips) {
      final status = trip['_uiStatus']?.toString() ?? 'new';
      if (status != 'new' || trip['_replying'] == true) continue;
      final remaining = remainingSeconds(
        trip,
        displaySeconds: displaySeconds,
        nowMs: nowMs,
      );
      if (trip['_remainingSeconds'] != remaining) {
        trip['_remainingSeconds'] = remaining;
        changed = true;
      }
    }

    // The old Home implementation also checked paused "new" trips when
    // removing expired records. Preserve that behavior exactly.
    for (final trip in trips) {
      if ((trip['_uiStatus']?.toString() ?? 'new') != 'new') continue;
      if (remainingSeconds(
        trip,
        displaySeconds: displaySeconds,
        nowMs: nowMs,
      ) <= 0) {
        expired.add(trip);
      }
    }
    return HomeTripTickResult(
      countdownChanged: changed,
      expiredTrips: expired,
    );
  }
}

class HomeTripTickResult {
  const HomeTripTickResult({
    required this.countdownChanged,
    required this.expiredTrips,
  });

  final bool countdownChanged;
  final List<Map<String, dynamic>> expiredTrips;

  bool get hasExpired => expiredTrips.isNotEmpty;
}
