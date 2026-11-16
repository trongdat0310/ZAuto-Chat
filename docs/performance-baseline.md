# ZCHATAUTO performance baseline and rollout (phase 0–1)

## Scope

Measure the real trip path before claiming any speed improvement:

Zalo listener → compiled filter → deduplication → trip store → WebSocket
broadcast → Flutter socket decode → Home event → first rendered trip frame.

The existing `ZAUTO_LATENCY_TRACE=1` option instruments this path. This
phase adds a percentile report and optional Node event-loop/CPU/RAM
monitoring. **No production measurements are included in this document.**

## 1. Prepare an isolated staging run

Use an Android device connected to the staging backend and your own test
Zalo group. Do not generate test traffic in a customer's live group. Ensure
the staging account and plan match the test. Record the Android version,
phone model, network, backend OS/storage, app commit, and sample count.

In a PowerShell terminal at `zauto-backend`:

```powershell
$env:ZAUTO_LATENCY_TRACE = "1"
$env:ZAUTO_PERF_METRICS = "1"
npm start 2>&1 | Tee-Object -FilePath .\backend-perf.log
```

`[PERF]` rows show p50/p95/p99 event-loop delay, CPU usage relative to one
CPU core, RSS memory and heap usage every 15 seconds. This is opt-in; remove
the two variables to disable profiling overhead in normal operation.

In another PowerShell terminal at `zauto_driver` (with ADB and USB):

```powershell
flutter run --profile
```

Generate a representative number of **actual new trip matches**. At the end
of the scenario, collect only latency lines from logcat:

```powershell
adb logcat -d -v time | Select-String '\[LATENCY\]' |
  Set-Content -Encoding utf8 .\trip-latency.log
```

Analyze the collected lines from `zauto-backend`:

```powershell
node scripts/latency-report.js ..\zauto_driver\trip-latency.log
node scripts/latency-report.js ..\zauto_driver\trip-latency.log --json
```

The report prints sample counts, p50, p95, p99 and maximum (milliseconds)
for each stage. It ignores lines that have no latency metrics.

**Important clock limitation:** backend `performance.now()` durations and
Flutter-only durations are the most reliable. Cross-device `network~` and
`total~` compare wall clocks and may be inaccurate even when positive.
Never report them as proven transport time unless the clocks are
synchronized and measured. The report marks negative differences as
`clock-skew`.

## 2. Scenarios

Run the same cases on the same hardware and network before/after each change:

| Scenario | Minimum observed sample goal | Important dimensions |
|---|---:|---|
| Cold start and login | 10 launches | first frame, first usable Home, reconnect |
| Realtime trip, foreground | 100 matching trips | filter, store, WS, Flutter first render |
| Bursty new messages | 100 matching trips | drops, duplicates, p95/p99, event loop |
| Chat with existing history | 10 chats | open time, scroll jank, memory |
| Background → foreground | 20 resumes | missing/duplicate events, resync |
| Two devices on the same app account | 20 events | WS fan-out and session rotation |
| 30-minute idle + active session | 1 run | CPU, RSS, timers, background polling |

The sample counts are targets for a staging measurement session, not current
measurements. Record any failures, disconnects and app-process restarts. For
UI responsiveness use Flutter DevTools in *profile* mode and observe frame
time, raster time and memory.

## 3. Acceptance criteria

1. Flutter `flutter analyze` and `flutter test` pass; backend `npm test`,
   `npm run test:performance`, security, subscription and payments tests pass.
2. Quota refresh keeps running after the last trip disappears and stops when
   Home is disposed. TripCard state follows its stable trip ID.
3. Password change/session version rotation and account deletion take effect
   immediately for in-process changes even with user-store caching.
4. No missing trip, duplicate accept/quota charge or false notification.
5. Report **measured** before/after p50/p95/p99. Revert a change if it
   worsens tail latency, increases error rate or fails regression tests.

## 4. Implementation boundaries

Phase 1 changes timer ownership, stable TripCard identity and cached user
lookups. It does **not** change billing, SePay, accept API semantics,
subscription expiration rules or the on-disk JSON schema.

The user snapshot cache has a 500 ms bound for **external file edits**;
writes made through `createUser`, `updateUser` and `deleteUser` refresh
it immediately, and mutations force a fresh disk read before writing.
Use one authoritative backend process for the JSON store. For multi-process
deployment, migrate to transactional persistence and explicit invalidation.

Store only aggregate timing output from diagnostics. Existing verbose backend
logs may contain message content or user details; do not upload raw logs to
issues, public CI artifacts or chat without redaction.

## 5. Follow-up phases

- Phase 2: measure JSON conversation persistence and event-loop stalls,
  then choose asynchronous ordering, bounded queues or DB migration based
  on results and durability tests.
- Phase 3: narrow Flutter rebuilds, reduce unnecessary REST refreshes, and
  improve direct message target seeking.
- Phase 4: refactor oversized modules with invariant tests.
- Phase 5: release-mode load tests, staged rollout, rollback and before/after
  report.
