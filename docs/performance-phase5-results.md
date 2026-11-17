# Phase 5 validation record — 17 November 2026

Project: ZCHATAUTO / repository `trongdat0310/ZAuto-Chat`,
branch `refactor/architecture`.

## Automated evidence

| Check | Result | Exact run |
|---|---|---|
| Backend unit/security/groups/subscriptions/payments | PASS, Node.js 22 and 24 | [Backend load run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44110605651) |
| Isolated synthetic replay, small | PASS | [Backend initial run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44109646132) |
| Isolated synthetic replay, 8 users x 200 unique messages | PASS, both Node versions | [Backend load run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44110605651) |
| Flutter static analysis | PASS: no issues | [Flutter quality run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44109755112) |
| Flutter unit/widget tests | PASS: 144/144 | [Flutter quality run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44109755112) |
| Android release-mode compile | PASS: 67.8 MB unsigned APK, package ID validated | [Android compile run](https://github.com/trongdat0310/ZAuto-Chat/actions/runs/44109755221) |

CI backend replay (Node.js 22) used **synthetic local fixtures only**:

| Metric | 3 users x 60 | 8 users x 200 |
|---|---:|---:|
| Input events | 243 | 2,152 |
| Matched events (duplicates included) | 216 | 1,920 |
| Duplicate events skipped | 36 | 320 |
| Filter-rejected events | 27 | 232 |
| Unique messages saved and verified | 180/180 | 1,600/1,600 |
| Processing p50 (ms) | 0.454 | 0.377 |
| Processing p95 (ms) | 0.723 | 0.972 |
| Processing p99 (ms) | 0.861 | 1.284 |
| Peak/snapshot RSS (MiB) | 63.0 | 105.9 |

The replay tests compiled filtering, deduplication, atomic conversation
storage, on-disk verification and temporary-data cleanup. It **did not**
run a real Zalo session, Cloudflare, WebSocket fan-out, phone rendering,
payment verification or ride acceptance. The RSS field is a snapshot at
the end of replay, not independently measured peak resident memory.
Reported p95/p99 are subject to the CI runner's hardware variance.

The Android build in CI deliberately lacked the release signing keystore.
Its SHA-256 (of the **unsigned CI output only**, not a user release) was:

```text
81c1649bef6334ef128991b64bb4f0f64bb77dacd771932b30402cd378c41fd3
```

Unsigned CI APKs are never published or approved for distribution.

## Manual release gates still open

- [ ] Privately signed release APK on Windows with existing trusted keystore
- [ ] `tool/release_readiness.ps1` and `tool/release_smoke.ps1` complete
- [ ] APK installed and launched successfully on a physical Android phone
- [ ] Actual Zalo groups, fast bursts and message-to-trip notifications
- [ ] WebSocket disconnect/reconnect with network off/on
- [ ] Background/resume, idle and 30-minute memory/battery observation
- [ ] Single and multi-device session invalidation and user isolation
- [ ] Acceptance idempotency, per-day/month quotas, add-ons and expiry
- [ ] Staging SePay webhook/repeated transaction verification
- [ ] Device frame timing and real end-to-end p50/p95/p99 baseline
- [ ] Version code, package ID, Firebase config and backup/rollback approved

**Decision:** code-level smoke and synthetic backend load gates PASSED;
**production release approval remains OPEN** until signed build and
device/staging checks complete.

See [the Phase 5 release procedure](performance-phase5-release.md).
