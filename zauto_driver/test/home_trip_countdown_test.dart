import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/home/home_trip_countdown.dart';

void main() {
  const now = 200000;

  test('remaining seconds are rounded up and capped at display time', () {
    expect(HomeTripCountdown.remainingSeconds(
      {'_expiresAtMs': now + 1001},
      displaySeconds: 15, nowMs: now,
    ), 2);
    expect(HomeTripCountdown.remainingSeconds(
      {'_expiresAtMs': now + 25000},
      displaySeconds: 15, nowMs: now,
    ), 15);
    expect(HomeTripCountdown.remainingSeconds(
      {'_expiresAtMs': now},
      displaySeconds: 15, nowMs: now,
    ), 0);
    expect(HomeTripCountdown.remainingSeconds(
      {'_remainingSeconds': 7},
      displaySeconds: 15, nowMs: now,
    ), 7);
    expect(HomeTripCountdown.remainingSeconds(
      {}, displaySeconds: 15, nowMs: now,
    ), 15);
  });

  test('reply pause and resume preserve remaining milliseconds', () {
    final trip = <String, dynamic>{'_expiresAtMs': now + 2301};
    HomeTripCountdown.pause(trip, displaySeconds: 15, nowMs: now);
    expect(trip['_pausedRemainingMs'], 2301);
    expect(trip['_expiresAtMs'], isNull);
    expect(HomeTripCountdown.remainingSeconds(
      trip, displaySeconds: 15, nowMs: now + 90000,
    ), 3);

    HomeTripCountdown.resume(
      trip, displaySeconds: 15, nowMs: now + 90000,
    );
    expect(trip['_pausedRemainingMs'], isNull);
    expect(trip['_expiresAtMs'], now + 92301);
    expect(trip['_remainingSeconds'], 3);
  });

  test('pause clamps expired trip to zero and fallback uses remaining seconds', () {
    final expired = <String, dynamic>{'_expiresAtMs': now - 1};
    HomeTripCountdown.pause(expired, displaySeconds: 15, nowMs: now);
    expect(expired['_pausedRemainingMs'], 0);

    final legacy = <String, dynamic>{'_remainingSeconds': 8};
    HomeTripCountdown.pause(legacy, displaySeconds: 15, nowMs: now);
    expect(legacy['_pausedRemainingMs'], 8000);
    HomeTripCountdown.resume(legacy, displaySeconds: 15, nowMs: now + 1000);
    expect(legacy['_expiresAtMs'], now + 9000);
    expect(legacy['_remainingSeconds'], 8);
  });

  test('tick updates only new active trips and identifies expiration', () {
    final active = <String, dynamic>{
      '_uiStatus': 'new', '_expiresAtMs': now + 2400,
      '_remainingSeconds': 5,
    };
    final accepted = <String, dynamic>{
      '_uiStatus': 'accepted', '_expiresAtMs': now - 10,
      '_remainingSeconds': 5,
    };
    final replying = <String, dynamic>{
      '_uiStatus': 'new', '_replying': true,
      '_pausedRemainingMs': 3000, '_remainingSeconds': 3,
    };
    final expired = <String, dynamic>{
      '_uiStatus': 'new', '_expiresAtMs': now - 1000,
      '_remainingSeconds': 1,
    };

    final trips = [active, accepted, replying, expired];
    expect(HomeTripCountdown.hasCountdownTrips(trips), isTrue);
    final result = HomeTripCountdown.tick(
      trips, displaySeconds: 15, nowMs: now,
    );
    expect(result.countdownChanged, isTrue);
    expect(active['_remainingSeconds'], 3);
    expect(accepted['_remainingSeconds'], 5);
    expect(replying['_remainingSeconds'], 3);
    expect(expired['_remainingSeconds'], 0);
    expect(result.expiredTrips, [same(expired)]);

    trips.removeWhere(result.expiredTrips.contains);
    expect(trips.length, 3);
    expect(HomeTripCountdown.hasCountdownTrips([accepted]), isFalse);
  });

  test('unchanged countdown produces no rebuild signal', () {
    final trip = <String, dynamic>{
      '_uiStatus': 'new', '_expiresAtMs': now + 3000,
      '_remainingSeconds': 3,
    };
    final result = HomeTripCountdown.tick(
      [trip], displaySeconds: 15, nowMs: now,
    );
    expect(result.countdownChanged, isFalse);
    expect(result.hasExpired, isFalse);
  });
}
