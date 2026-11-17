# ZCHATAUTO — Phase 4 architecture refactor (increment 1)

**Scope:** Flutter Home and Messages. This is a behavior-preserving
refactor, not a new trip acceptance, membership, payment or Zalo feature.

## Home: extract trip presentation state

`lib/pages/home/home_page.dart` no longer owns the 180-line countdown
implementation or the ~230-line REST trip reconciliation routine.

- `home_trip_countdown.dart` owns time calculations, pause/resume, and
  countdown tick decisions. The app passes `nowMs` explicitly, so tests
  cover expiration boundaries without waiting for timers.
- `home_trip_reconciler.dart` merges the backend's pending trips with the
  local active list. It preserves optimistic `accepting`/`ignoring` and
  completed statuses, retains trips arriving after a REST request began,
  and restores pending cards without replaying audio/push.
- Home retains `setState`, notification, audio and API ownership.
  A regular one-second tick continues to update the badge only, not the
  entire screen. An expired trip removes its card inside `setState`.

**Validation:** `home_trip_countdown_test.dart`,
`home_trip_reconciler_test.dart`, `home_timer_controller_test.dart`,
`trip_card_countdown_test.dart`, and other existing Flutter tests.

## Messages: extract optimistic-state reconciliation

`lib/pages/messages_page.dart` delegates optimistic REST merge and
conversation ordering to `messages_state_merge.dart`:

- Exclude conversations while their delete operation is pending.
- Keep local pin status and timestamp while a request is pending, and
  use backend truth after the pending flag clears.
- Merge group notification toggles pending locally with server results.
- Preserve pinned-first, latest-pin, latest-message ordering.
- The existing resource-scoped realtime refresh and 350 ms invalidation
  debounce are not changed.

**Validation:** `messages_state_merge_test.dart`,
`messages_refresh_plan_test.dart`, and existing Flutter tests.

## Test commands

```powershell
cd C:\Project\zauto_driver
git pull --rebase origin refactor/architecture
flutter analyze
flutter test test/home_trip_countdown_test.dart
flutter test test/home_trip_reconciler_test.dart
flutter test test/messages_state_merge_test.dart
flutter test
flutter run --profile
```

Perform an on-device regression: simultaneous cuocs, reply pause/resume,
timeout, quick accept, network reconnect, group notification toggle,
pin/unpin/delete while REST is in flight, and history tab navigation.
Compare frame time, allocations, and latency against the previous
stage; the refactor itself is not proof of a speedup.

## Design constraints / next increments

The data contracts currently use `Map<String, dynamic>` and the backend
remains authoritative. Introducing typed DTOs and a full controller rewrite
should be gradual, with compatibility tests for legacy payload fields.

Remaining Phase 4 work: audit `chat_page.dart` boundaries and extract
cohesive state/formatting rules where tests can demonstrate unchanged
behavior; review inactive tab work and prevent redundant rebuilds while
preserving realtime catch-up. Phase 5 includes staged load tests,
production-like profile measurements and rollback gates.

Do not change subscription counting, SePay reconciliation, stored message
schemas, or existing acceptance deduplication as a side effect of refactoring.
