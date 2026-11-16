# ZCHATAUTO — Phase 3, increment 1: Flutter frame work and HTTP reuse

## Changes

### Home countdown

Previously Home called `setState()` every second while an active trip was
counting down. This rebuilt the quota header and the visible trip cards even
when only the countdown number changed.

The countdown ticker now updates each trip's remaining seconds and notifies
a shared `ValueNotifier`. Each `TripCard` uses a `ListenableBuilder`
around its **countdown badge only**. Home calls `setState()` on ticker
events when a trip actually expires and is removed, preserving list
semantics. The notifier is disposed along with the Home timer controller.

The optional `countdownRefresh` parameter preserves existing TripCard
callers and tests that do not supply a clock. Processing, reply and ignore
buttons continue to be controlled by the card's existing callbacks.

### HTTP keep-alive

`BackendApiBase` previously used `http.get/post/patch/put` convenience
functions and `BaseRequest.send` per request. Those helper methods create
and close their own `http.Client` instead of retaining a connection pool.

All backend API base methods now reuse one process-lifetime `http.Client`
for GET/POST/PATCH/PUT/DELETE/multipart. Auth headers are generated for **each**
request as before. A test-only injectable client is available via the
`BackendApiBase` constructor, making it possible to verify request headers,
methods and 401 handling without reaching a real server.

This reduces connection setup opportunities but **does not reduce the
number of REST requests** and is not proof of a network latency reduction.
Session invalidation and request timeouts are unchanged.

## Tests / validation

From `zauto_driver`:

```powershell
flutter analyze
flutter test test/home_timer_controller_test.dart
flutter test test/trip_card_countdown_test.dart
flutter test test/trip_card_open_message_test.dart
flutter test test/backend_api_client_test.dart
flutter test
flutter run --profile
```

In profile mode, compare Home while 1, 10 and 30 simultaneous trips count
down. Observe Build and Raster frame times and CPU using Flutter DevTools;
repeat at the same display refresh rate and Android device.

For HTTP, compare repeat requests while logged in (e.g., opening Messages
and refreshing membership). Measure latency on stable Wi-Fi before and
after. The new client should keep TCP/TLS connections where supported;
proxy/server keep-alive policies and network changes can affect outcomes.

## Remaining Phase 3 work

- Coalesce or scope the Messages page's three parallel REST loads after
  realtime events. Current `loadData()` correctly coordinates concurrent
  loads but still refreshes accepted trips, conversations and groups
  together; preserve reconnect reconciliation and optimistic pending edits.
- Avoid unnecessary work by tabs that are not visible, without dropping
  realtime updates and without surprising stale data on return.
- Profile direct chat target seeking and cached avatar/media decoding.
- Gather real on-device frame histograms and p95 API timings before
  claiming quantitative improvements.

No billing, accept/idempotency, subscription or payment semantics are
changed in this phase.
