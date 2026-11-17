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

## Chat: isolate stable presentation rules

`chat_page.dart` now delegates UI-only metadata rules to
`chat_message_presentation.dart`: recall timeout eligibility, timestamp
formatting, Zalo mentions (including `propertyExt`), fallback text,
and stable message keys. `chat_mention_text_controller.dart` owns the
composer prefix highlight without altering the outgoing text. The existing
realtime, paginated message search, acceptance and backend message
controllers are not changed. Eight deterministic tests guard the refactor.

## Inactive tabs: suspend presentation work, keep realtime

The existing `IndexedStack` preserves pages when the user switches tabs.

- **Home**: if `isActive` is false or the app is not resumed, stop the
  30-second quota refresh and one-second countdown UI ticker. Keep the
  realtime service, notifications and trip state alive. When Home becomes
  visible, refresh quotas/summary and recalculate countdown seconds from
  absolute expiry timestamps. Do not restart a paused countdown from a
  stale number. `HomeTimerController.setVisibleWork` is unit-tested.
- **Messages**: `isActive` is passed from MainScreen. On cold start, avoid
  requesting history, conversations and groups until Messages is first
  opened. Continue receiving realtime events in the background, but union
  their REST invalidation scopes without starting a debounce timer or HTTP.
  On activation, fetch the queued resources. After 45 seconds without a
  complete refresh, a full reconciliation covers out-of-band edits.
  Manual refresh, active-tab realtime updates and existing authentication
  reconciliation are unchanged.

This reduces avoidable background requests and countdown widget work. It
**does not** disable listening for new trips or notifications. No percentage
improvement is claimed without measuring actual network traffic and frame
timings.

## Test commands

```powershell
cd C:\Project\zauto_driver
git pull --rebase origin refactor/architecture
flutter analyze
flutter test test/home_trip_countdown_test.dart
flutter test test/home_trip_reconciler_test.dart
flutter test test/messages_state_merge_test.dart
flutter test test/chat_message_presentation_test.dart
flutter test test/chat_mention_text_controller_test.dart
flutter test test/messages_refresh_plan_test.dart
flutter test test/home_timer_controller_test.dart
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

Remaining Phase 4 refactors should only be considered after the
on-device regression confirms there is no stale chat, missed trip or
background notification. Phase 5 includes staged load tests, production-like
profile measurements (CPU/RAM, frames, p95/p99) and rollback gates.

Do not change subscription counting, SePay reconciliation, stored message
schemas, or existing acceptance deduplication as a side effect of refactoring.
