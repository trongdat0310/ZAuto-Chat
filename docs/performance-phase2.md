# ZCHATAUTO Phase 2 — conversation I/O and realtime hot path

## Implemented in this increment

1. New message history files (and rewritten existing ones) use compact JSON
   instead of 2-space pretty-printed JSON. Conversation indexes retain their
   previous formatted JSON. **The schema and read APIs are unchanged.**
2. Atomic persistence stays synchronous: create the temporary file, fully
   write it, then rename it into place. There is **no asynchronous
   write-behind queue** in this change. A successful save returns only after
   the rename completes; the change does not weaken the existing durability
   model.
3. The Zalo message listener no longer awaits an already-resolved sticker
   enrichment task for ordinary text messages. Actual sticker messages are
   enriched before continuing as before.
4. Routine filter rejections, duplicate notifications and trip matches no
   longer print detailed logs on the hot path. Optional diagnostic records
   have no sender, group ID/name, message text, keyword or user ID.
5. Routine WebSocket broadcasts no longer log per-event user IDs by default.
6. Add optional I/O aggregation for the actual synchronous conversation file
   writes, separated by `messages` and `index`, with p50/p95/p99,
   maximum and total bytes written for each 50 successful writes.

## Benchmark on staging

From `zauto-backend`:

```powershell
npm test
npm run test:performance
npm run benchmark:conversations
npm run benchmark:conversations -- --messages=5000 --runs=25
```

The benchmark uses synthetic messages only. It compares old pretty JSON and
new compact JSON in one process and reports bytes plus CPU serialization
time. **It does not measure disk writes, Zalo delivery or phone display
latency.** Times are susceptible to JIT warm-up, CPU throttling, and
benchmark order; do not interpret one run as a guaranteed speed-up.

To measure real I/O with the existing perf flags on a staging backend:

```powershell
$env:ZAUTO_PERF_METRICS = "1"
$env:ZAUTO_LATENCY_TRACE = "1"
npm start 2>&1 | Tee-Object .\performance-stage.log
```

Watch `[CONVERSATION IO]` (in milliseconds) and `[PERF]` (event-loop delay,
CPU, memory). Compare p95/p99 at the same user load and storage hardware.
`[LATENCY]` from the Flutter client is analyzed with
`npm run report:latency -- <path-to-log>`.

`ZAUTO_VERBOSE_TRIP_LOGS=1` and `ZAUTO_VERBOSE_WS_LOGS=1` are optional
diagnostics only. Leave both unset for normal operation.

## Regression matrix

- Repeat a Zalo message: still deduplicated by original message identifiers
- Load chat history and cursor pages: same message order and content
- Restart backend: all completed atomic writes reload correctly
- Existing pretty JSON: can still be read and next write becomes compact
- Deleted/hidden conversations, recalled messages, private chats: existing
  conversation tests remain mandatory
- Foreground and background delivery, accepted trip and quota: existing
  suites remain mandatory
- WebSocket auth/session checks, per-user isolation: unaffected

## Remaining work (do not skip)

The persistence path still rewrites each conversation's entire message
history and conversation index on every new saved chat message. Its CPU and
event-loop cost is therefore still O(history size). Batching or converting
to async writes is deferred until the measured staging results justify it,
with per-conversation serialization, crash/restart and partial-write tests,
and a recovery/rollback plan. A transactional store may be the safer
long-term option if chat volume rises.

Do not delete or rewrite on-disk user data for a performance test.
Always back up before a storage-engine migration. Use one authoritative
backend process for the current JSON storage format.

## Quality gates

Run `npm test`, `npm run test:performance`,
`npm run test:security`, `npm run test:subscriptions`,
`npm run test:payments`, `npm run test:groups`, and
`flutter analyze`, `flutter test` before changing production behavior.
The GitHub Actions backend workflow runs the backend suites and synthetic
serialization benchmark; timing results are informational, not a CI
performance threshold.
