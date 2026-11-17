import 'package:flutter_test/flutter_test.dart';
import 'package:zauto_driver/pages/home/home_trip_reconciler.dart';

void main() {
  const startedAtMs = 100000;
  const nowMs = 102000;

  Map<String, dynamic> pending(String id, int remainingMs) => {
        'id': id,
        'content': 'Cuốc $id',
        '_reconcileRemainingMs': remainingMs,
      };

  void reconcile(List<Map<String, dynamic>> trips,
      Iterable<Map<String, dynamic>> remote, {int displaySeconds = 15}) {
    HomeTripReconciler.apply(
      activeTrips: trips,
      pending: remote,
      displaySeconds: displaySeconds,
      reconcileStartedAtMs: startedAtMs,
      nowMs: nowMs,
    );
  }

  test('removes old stale trips but preserves local in-flight outcomes', () {
    final trips = <Map<String, dynamic>>[
      {'id': 'stale', '_uiStatus': 'new', '_addedAtMs': 90000},
      {'id': 'accept', '_uiStatus': 'accepting', '_addedAtMs': 90000},
      {'id': 'ignore', '_uiStatus': 'ignoring', '_addedAtMs': 90000},
      {'id': 'accepted', '_uiStatus': 'accepted', '_addedAtMs': 90000},
      {'id': 'ignored', '_uiStatus': 'ignored', '_addedAtMs': 90000},
    ];
    reconcile(trips, []);
    expect(trips.map((t) => t['id']),
        ['accept', 'ignore', 'accepted', 'ignored']);
  });

  test('REST never deletes trips that arrived after reconciliation began', () {
    final realtimeTrip = <String, dynamic>{
      'id': 'new-realtime',
      '_uiStatus': 'new',
      '_addedAtMs': 100001,
      'content': 'Realtime newer than API',
    };
    final trips = [realtimeTrip];
    reconcile(trips, []);
    expect(trips, [same(realtimeTrip)]);
  });

  test('restores pending trips and retains ordering without duplicate cards', () {
    final trips = <Map<String, dynamic>>[];
    final server = [pending('a', 2400), pending('b', 40000)];
    reconcile(trips, server);
    expect(trips.map((t) => t['id']), ['a', 'b']);
    expect(trips[0]['_uiStatus'], 'new');
    expect(trips[0]['_remainingSeconds'], 3);
    expect(trips[0]['_expiresAtMs'], nowMs + 2400);
    expect(trips[0]['_addedAtMs'], nowMs);
    expect(trips[1]['_remainingSeconds'], 15);
    expect(trips[0]['_pausedRemainingMs'], isNull);

    reconcile(trips, server);
    expect(trips.length, 2);
    expect(trips.map((t) => t['id']), ['a', 'b']);
  });

  test('updates a matching card in place to preserve Flutter widget state', () {
    final current = <String, dynamic>{
      'id': 'same',
      'content': 'Old',
      '_remainingSeconds': 7,
      '_uiStatus': 'new',
      '_addedAtMs': 90000,
      '_replying': false,
    };
    final trips = [current];
    reconcile(trips, [pending('same', 2000)]);
    expect(identical(trips.single, current), isTrue);
    expect(current['content'], 'Cuốc same');
    expect(current['_remainingSeconds'], 2);
    expect(current['_expiresAtMs'], nowMs + 2000);
  });

  test('never overwrites accepting or accepted cards with pending REST data', () {
    final accepting = <String, dynamic>{
      'id': 'same', 'content': 'In flight', '_uiStatus': 'accepting',
      '_remainingSeconds': 6,
    };
    final accepted = <String, dynamic>{
      'id': 'finished', 'content': 'Already accepted',
      '_uiStatus': 'accepted',
    };
    final trips = [accepting, accepted];
    reconcile(trips, [pending('same', 14000), pending('finished', 14000)]);
    expect(trips.length, 2);
    expect(accepting['content'], 'In flight');
    expect(accepting['_uiStatus'], 'accepting');
    expect(accepted['content'], 'Already accepted');
  });

  test('skips missing IDs and invalid or expired server windows', () {
    final trips = <Map<String, dynamic>>[];
    reconcile(trips, [
      pending(' ', 8000),
      pending('zero', 0),
      pending('negative', -1000),
      {'id': 'wrong', '_reconcileRemainingMs': '10'},
      pending('valid', 1),
    ]);
    expect(trips.length, 1);
    expect(trips.single['id'], 'valid');
    expect(trips.single['_remainingSeconds'], 1);
  });

  test('duplicate server IDs use the final entry without duplicating UI', () {
    final trips = <Map<String, dynamic>>[];
    reconcile(trips, [pending('same', 6000), pending('same', 9000)]);
    expect(trips.length, 1);
    expect(trips.single['_remainingSeconds'], 9);
  });
}
