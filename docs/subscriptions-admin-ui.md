# Subscription administration and acceptance history

This increment continues `feature/subscriptions-chat-accept-2026-10-14` / draft PR #17.
It does not merge into `main`, deploy a server, create an account, or add payments.
Read `subscriptions-chat-accept.md` first for the existing reservation store and recovery precautions.

## Open the screens

In the Flutter app: **Tai khoan -> Goi su dung**. The new page shows the current/expired
plan, start/end dates, remaining/used/reserved credits per receive mode, and today's add-ons.
Dates are displayed in Vietnam time (UTC+7). Unlimited is displayed without a numeric cap.
The auto-accept allowance is explicitly labeled as reserved for a feature not implemented yet.

Only a server response with `isAdmin: true` displays **Quan ly tai khoan va goi**.
The backend checks authority again for every read and mutation; hiding the button is not security.
An administrator can search by phone/name (including +84 and accent-insensitive names), page
through users, select an account, assign/change a main plan, renew, add credits, revoke, view
audit records, and reconcile a delivery with an uncertain outcome.

The previous `account_page.dart` implementation is preserved verbatim as
`account_profile_page.dart`. A small wrapper retains the original callbacks and inserts the
subscription entry without changing account login, logout, deletion or Zalo-link behavior.

## Bind the administrator on the server

Use the existing account registered with phone `0911111111`:

```sh
cd zauto-backend
node scripts/find-admin-user.js 0911111111
```

Copy the printed `ADMIN_USER_ID=...` into the existing server `.env`, then restart the backend.
Do not replace the rest of `.env` or create a default password. No matching ID means no admin
access. Client-supplied `role`, `actorId`, `phone`, `userId` or receive feature cannot grant authority.
This code update does not change production environment variables.

## Grant versus renew

* **Grant/change:** starts a new main subscription immediately, replacing its current allowance.
  Previous counters and accepted-target deduplication remain for audit. Existing active add-ons
  remain until their original expiry. The confirmation dialog explains the allowance reset.
* **Renew active:** extends its end date, preserving its ID/start and the credits already consumed
  in the current daily/monthly bucket. Calendar anniversaries use the original start, including
  Jan 31 -> Feb 28 -> Mar 31. Valid durations are integer 1..24 months.
* **Renew expired:** starts a fresh cycle now using the previous main plan, with a new subscription
  ID. It does not bill for the gap or revive expired add-ons. A revoked/nonexistent plan must be
  granted again instead of renewed.
* **Add-on:** requires an active main plan; expires at the next Vietnam midnight. Credits are
  independent per feature. Expiring add-ons are consumed before main allowance.
* **Revoke:** removes the main plan/add-ons for future sends. It does not cancel an external send
  already in flight, erase the audit/acceptance ledger, or allow the same target to be resent.

## API contract

Existing JWT bearer authentication is required on every route below.

| Method and path under `/api/subscriptions` | Purpose |
| --- | --- |
| GET `/plans` | Seven plan definitions; no pricing |
| GET `/me` | `isAdmin`, subscription, `revision`, server time and feature balances |
| GET `/me/history` | Up to 500 accepted trips, merged from trip cache and success ledger |
| POST `/trips/:id/accept` | Metered screen receive with structured quota/409 errors |
| POST `/chat/accept` | Metered tap receive; ordinary conversation send is unchanged |
| GET `/admin/users?q=&offset=0&limit=25` | Search and page safe user fields only |
| GET `/admin/users/:id` | User, subscription, pending operations, per-user audit |
| POST `/admin/users/:id/plan` | Assign `{planId, months, ...command}` |
| POST `/admin/users/:id/renew` | Renew `{months, ...command}` |
| DELETE `/admin/users/:id/plan` | Revoke with JSON command body |
| POST `/admin/users/:id/resolve` | `{targetKey, outcome, ...command}` |
| GET `/admin/logs?userId=...` | Last 200 audit events, optionally restricted to that user |

All admin writes now require these command fields (including DELETE):

```json
{
  "requestId": "one-random-id-per-confirmed-action",
  "expectedRevision": "copy-the-64-character-revision-from-the-latest-subscription-response",
  "note": "optional reason; mandatory 5..500 characters for reconciliation"
}
```

`requestId` is 8..128 ASCII letters/digits/underscore/hyphen. The Flutter dialog generates a
cryptographically random ID once. After an ambiguous response it locks the original payload and
retries that same ID. The result is persisted atomically with the mutation, so retrying after a
restart does not renew or grant twice. Reusing an ID for another payload gives
`REQUEST_ID_CONFLICT` (409). A different command with a stale revision gives
`SUBSCRIPTION_CHANGED` (409); reload and confirm the new state. No automatic force-overwrite.
The old bare admin API payloads must be updated; they now fail validation instead of mutating.

## Acceptance history and realtime

New receive operations persist a server-derived snapshot of the original group/message/sender
before sending. After a confirmed chat send, a local accepted trip is projected into the existing
trip store and a user-scoped `trip_accepted` event updates the active trip screen. `getAcceptedTrips`
in Flutter now uses `/me/history`, which merges ledger successes with the existing cache and
collapses original message/CLI aliases. An older operation without a snapshot is retained in the
ledger; missing original content may not be recoverable automatically.

A projection/socket failure does not send again or subtract another credit. The response includes
`historySyncPending` if the local projection failed; GET history can still return the ledger success.
The open history view must refresh/reopen to fetch it; this increment does not promise that every
already-open history sheet rebuilds immediately. The personal subscription page refreshes on open,
resume, manual refresh and every minute while current. It can consume an injected event stream;
the existing account wrapper does not create another websocket connection.

After a send starts, a timeout is not proof of non-delivery. Admin must verify Zalo before choosing
`succeeded` (count held credit once) or `failed` (release it). A review note is mandatory. Actively
`reserved`/`sending` operations cannot be released through the reconciliation UI. Process crashes
and stale file locks still require the manual, offline recovery described in the earlier document.

## Verification performed in this workspace

Node 22.16.0, isolated temporary files and mocked send functions:

```sh
cd zauto-backend
npm run test:subscriptions
```

**85 tests passed, 0 failed:** 34 existing tests plus 51 new admin/renewal/history tests.
Coverage includes permissions, safe user search/pagination, stale revision conflicts, retry after
lost responses/restart, renewal boundaries, duplicate add-on prevention, quota reservations,
account isolation, chat mention context, history merge, secondary-store/socket failures and
uncertain-delivery reconciliation. Changed JavaScript files were syntax-checked with `node --check`.
No real Zalo messages were sent and no production data was changed.

Seven new Dart/widget tests are supplied in `test/subscription_admin_test.dart`, in addition to the
previous chat tests. Run on a machine with this project's Flutter/Dart SDK:

```sh
cd zauto_driver
flutter pub get
flutter analyze
flutter test
```

Flutter SDK/dependencies were not available here: these widget tests, analysis, Android/iOS build,
real gestures/mentions and the complete existing backend suite were NOT run. Do not interpret the
85 pure Node tests as an end-to-end production certification. Use a staging server and update both
backend and app together; new client endpoints do not exist on an old backend. The legacy screen
accept endpoint is retained for older clients but its old error mapping is unchanged.

## Remaining scope

Actual automatic receiving, payments, multi-host transactional storage, real-device/Zalo end-to-end
validation, and operational reconciliation after process crashes are not completed by this increment.
The JSON quota ledger is still a single-host/local-disk design; the trip cache is process-local.
Use a single backend process for this release candidate. Back up `data/` before testing upgrades.
Keep PR #17 in Draft until Flutter/device and server integration testing is completed.
