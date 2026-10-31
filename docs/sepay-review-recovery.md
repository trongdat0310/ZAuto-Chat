# Recover receipts affected by truncated SePay codes

This LOCAL operator tool handles ONLY `review / MISSING_OR_AMBIGUOUS_CODE`
receipts where the original stored bank content contains one complete order code
and SePay's shorter `code` is its prefix. No public endpoint is added.

## Read-only first

From the existing backend directory (same .env, users and subscriptions file):

```powershell
cd C:\Project\zauto-backend
node --test src/payments/payment-reconciliation.test.js
npm run payments:reconcile -- --transaction YOUR_SEPAY_ID
```

Without `--apply` the command is read-only. `eligible: true` means the stored
receipt passes technical checks, NOT that a human has verified bank settlement.
Inspect orderId, userPhone, userId, planId, amount, expectedAmount, bankReference,
transactionDate, action (assign/renew/addon), expiry and approval.

Compare against VPBank/SePay: genuine incoming transaction, correct reference,
account, amount, time, complete transfer content and intended ZAutoChat account.
Confirm no prior manual package grant, refund or compensation for this payment.
Do NOT transfer again and do NOT delete receipt, order, reference or lock files.
Two separate valid payments for two orders can grant/renew TWO periods, even if
the amounts match. Do not approve both merely because they appear in the report.

## Applying one verified receipt

Use the exact values from a fresh preview, and an existing ADMIN_USER_ID in .env:

```powershell
npm run payments:reconcile -- --transaction YOUR_SEPAY_ID --order ZCA_FULL_CODE --approve PREVIEW_HASH --bank-reference BANK_REFERENCE --bank-verified --not-previously-credited --note "Verified in VPBank; not previously credited or refunded" --apply
```

Placeholders must be replaced; do not use a guessed order or reference.
The tool makes a private backup under `data/payment-review-backups/` before the
write. Keep backups off GitHub. The store repeats validation under its existing
cross-process lock and commits receipt, paid order, entitlement and audit together.
The original raw payload, fingerprint, first receivedAt and prior review reason
remain recorded; bank-reference deduplication is preserved.

The apply command is a local bookkeeping/entitlement operation, not a bank charge
or refund. It requires explicit operator confirmation. Normal webhook replays
continue to retain reviews; there is no automatic approval switch.

Preview hash binds the whole store snapshot and current VN day. If any process
changes the data, `REVIEW_CHANGED` is expected: run a NEW preview, recheck and retry.
After applying the first receipt, run a new preview for the second receipt.
Do not bypass errors or edit JSON to force success. Missing/ambiguous code, wrong
amount, wrong bank/account, outside-window transfer, inconsistent evidence,
conflicting bank reference, deleted user or a changed active plan are blocked.
A monthly transfer made inside its payment window may be reconciled after order
expiry; a daily add-on crossing to another VN day is still blocked for review.

## After successful apply

Refresh the original checkout (same browser/tab and checkout token). It should
report paid when querying the correct local data file. Pull to refresh Home.
Do not recreate the order or send more money. `npm run payments:report` is still
read-only. If the original checkout token was lost, use the local report to check
the result; do not expose tokens/raw bank payload publicly.

No restart is required for the one-shot CLI itself after pulling code. Restart
`payments:local` to load the latest code for future webhooks. Keep the existing
Cloudflare process running to retain its temporary URL.

## Validation scope

35 targeted Node tests use in-memory transactional fixtures plus the actual
payment confirmation/security modules. They cover read-only preview, duplicate
replay, two payments, stale approval, failed commit, evidence integrity and all
major rejection paths. These are NOT a real bank test, Windows file I/O test or
a full end-to-end test of the user's local deployment. No live receipt was
approved while developing this tool.
