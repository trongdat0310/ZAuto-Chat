# ZCHATAUTO — Phase 5: synthetic load, Android compile and release gates

## What is implemented

1. `zauto-backend/scripts/synthetic-replay.js`: isolated multi-user replay
   of the **real compiled group filter**, 5-second message dedupe and
   **real atomic conversation JSON persistence**. It checks the final
   message count, unique Zalo message IDs, duplicate store idempotency
   and absence of orphan `.tmp` files. Source data is synthetic only.
2. Each run creates a unique OS temporary directory and copies the relevant
   conversation-store modules into it. All user data from the replay is
   removed in `finally`, even on an exception; the live backend data
   directory, payment services, Zalo client and authentication are untouched.
3. `npm run test:load` asserts replay counts and input bounds. CI runs the
   tests and a small replay on Node.js 22 and 24. **Latency numbers are
   informational; no hardware-dependent speed threshold fails CI.**
4. `android-build-validation.yml`: compile Android in release mode on
   GitHub Actions without any signing material. Check the APK archive and
   package ID. This is an **UNSIGNED, NON-DISTRIBUTABLE build check**; no
   APK artifact is uploaded.
5. `zauto_driver/tool/release_readiness.ps1`: local Windows preflight
   for a **privately signed** release APK. Checks clean source, HTTPS backend,
   Flutter analyzer/tests, release compilation, APK signature via apksigner,
   file size and SHA-256. It does not publish, install, uninstall or send an APK.

## 1. Isolated synthetic backend workload

From `C:\Project\zauto-backend`:

```powershell
git pull --rebase origin refactor/architecture
npm ci
npm run test:load
npm run load:synthetic
npm run load:synthetic -- --users=8 --messages=200 --duplicates-every=5 --reject-every=7
```

The default workload is 3 test users x 60 unique synthetic messages,
including duplicate and unmatched events. It caps at 12 users x 300 unique
messages, to avoid accidentally generating a production-like flood.
Report fields include `inputEvents`, `matched`, `duplicatesSkipped`,
`rejected`, `saved`, `persisted`, `processingMs.p50/p95/p99`,
`eventsPerSecond`, and RSS in MiB.

**Do not interpret these timings as time-to-display a cuốc.** The replay
does NOT run actual Zalo, Node HTTP listener/WebSocket fan-out, client app,
Cloudflare Tunnel, phone notifications, acceptance/quota transactions, or
network. Use an isolated staging backend and devices to measure those.

## 2. Android release compile versus distributable signed APK

GitHub Actions `Android unsigned compile validation` checks whether the
current Flutter project compiles a release APK. The output deliberately
does **not** use the private signing key and is **never distributed**.

For a real signed APK, prepare `android/key.properties` on the Windows
build machine using `tool/setup_release_signing.ps1` if not already done.
Back up the upload keystore securely. Never paste its passwords into
source code, chat, GitHub secrets in logs or CI output.

From `C:\Project\zauto_driver`, with no local uncommitted changes:

```powershell
git pull --rebase origin refactor/architecture
powershell -ExecutionPolicy Bypass -File .\tool\release_readiness.ps1
```

Use a test backend via
`-BackendUrl https://your-staging-api.example` only if it is a controlled,
trusted HTTPS server. This argument is embedded at build time.

The script refuses missing release signing config or unsigned APKs.
An existing signed APK may be rechecked without rebuilding:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\release_readiness.ps1 -UseExistingApk
```

This abbreviated path skips compile/analyze/test; it is not equivalent
to a complete preflight. For install + launch testing on a USB-connected
Android device, explicitly run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\release_smoke.ps1
```

Avoid `-ReplaceExisting` unless you explicitly accept uninstalling the
old app and losing its local device data. Keep the signing key identical
between upgrades.

Before a public version, confirm the **production package ID** (currently
`com.example.zauto_driver`), Firebase `google-services.json` and
`pubspec.yaml` versionName/versionCode. The repository currently uses
`1.0.0+1`; any new public version must be deliberately versioned.

## 3. Real device and backend staging validation (not automated in CI)

| Scenario | Trial goal | Failure criterion |
|---|---:|---|
| App cold start + first usable Home | 10 launches | crash/hang |
| 100 real matching group messages | 100 | dropped or duplicate visible cuốc |
| Bursty incoming cuốc | >=100 | duplicate acceptance or quota deduction |
| Chat target jump, older pages, media | 10 chats | wrong message/scroll error |
| Wi-Fi off/on or tunnel restart | 20 reconnections | missed reconciliation or stale state |
| Background/resume, 30-min idle | 30 minutes | repeated timers, battery drain |
| Two clients logged into same test account | 20 events | cross-user leak, invalid session behavior |
| Membership expiring, empty quota, add-on | representative | incorrect quota or reminder |
| SePay test callback and transaction replay | controlled staging | double credit, incorrect amount |

Use **test accounts and test groups**, not production traffic. For network
offline/on tests, restore connectivity and confirm Home and Messages
eventually reconcile. Validate both the quota count and acceptance history.

From a profile session in `zauto_driver`:

```powershell
flutter run --profile
adb logcat -d -v time | Select-String '\[LATENCY\]' |
  Set-Content -Encoding utf8 .\trip-latency.log
```

From `zauto-backend`:

```powershell
node scripts/latency-report.js ..\zauto_driver\trip-latency.log
```

Compare p50/p95/p99 on the same phone, network and backend with the phase 0
baseline; record failed events separately. Use Flutter DevTools frame chart
for build/raster time, and `ZAUTO_PERF_METRICS=1` on **staging** for
Node event loop, CPU and memory. Backend `performance.now()` durations
are trustworthy; wall-clock-derived `network~`/`total~` can be skewed
between the phone and server.

## 4. Go/no-go and rollback

**Automated gates**
- No Flutter analyzer failures or failed widget/unit tests.
- All backend suites: tests, performance, load replay, security, group,
  subscription and payments.
- Android release-mode compile succeeds, not mistaken for signed release.
- Signed release passes `release_smoke.ps1 -SkipInstall`; SHA-256 recorded.

**Manual release gates**
- Android smoke/install and all critical acceptance/notification scenarios.
- No duplicate quota debit, duplicate acceptance, missing cuốc or data loss.
- No measurable p95/p99 regression versus approved device baseline.
- Cloudflare URL, account auth, backup/restore, Firebase and webhook checks
  performed against staging without exposing customer data.

**Stop release** immediately on lost trips, incorrect quota deductions,
data corruption, security failure or unacceptable frame stutter. Keep the
last known-good signed APK, version, commit SHA and compatible backend
backup. Roll back with a reviewed `git revert`/rebuild and restore data
only from a tested backup when necessary. Do not use destructive resets
against live accounts or auto-uninstall users' apps.

**Current status:** automated tools and CI checks exist; the signed APK,
Android device, real Zalo, Cloudflare latency and production readiness
have NOT been validated by this document. User approval is required before
deploying production or distributing an APK. Never post unredacted backend
logs, sensitive tokens, or keystores.
