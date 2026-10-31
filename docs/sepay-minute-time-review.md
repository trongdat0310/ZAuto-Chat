# Local review of a possible minute-resolution bank timestamp

This extends `sepay-review-recovery.md`. It does NOT assert that VPBank or SePay
always round timestamps. A `:00` value alone is not proof of minute precision.
It does not change normal webhook time checks or automatically approve receipts.
No bank transfer, refund or live payment reconciliation is performed by installing
this code. Only the operator's explicit local `--apply` can change entitlements.

## Scope

The option applies only to stored `review / MISSING_OR_AMBIGUOUS_CODE` receipts
already supported by the recovery tool. The original full bounded order code must
exist in the signed bank content, with the provider's shorter code as its prefix.
The amount, receiver, reference, user, active plan, receipt integrity, deduplication
and expiry checks remain enforced. The bank timestamp must be exactly `:00`, in
the SAME calendar minute as order creation, less than 60 seconds before creation.
The original receipt must have arrived after order creation and not in the future.
Previous minutes, nonzero early seconds and transfers after expiry are rejected.

Example: bank `2026-10-31 22:20:00` vs order `2026-10-31T15:20:04.298Z` differs
by 4.298 seconds, not seven hours. Exact matching still rejects it by default.
Only after the operator verifies the actual bank record and its time precision
should the same-minute interpretation be used for applying a payment.

## Preview (read only)

From the backend folder with the existing .env and data:

```powershell
node --test src/payments/payment-minute-time.test.js
npm run payments:reconcile -- --transaction YOUR_SEPAY_ID --vpbank-minute-time
```

Without `--apply`, data is not written. The result includes `timeCheck`, with
`beforeOrderByMs`, `sameMinuteCandidate`, `policy` and `toleranceApplied`.
`eligible: true` is a technical check result, not proof of bank settlement or
rounding. Confirm the intended recipient account, actual incoming bank reference,
amount, full memo and timing, with no prior manual credit, refund or compensation.
Keep disputed evidence in review rather than forcing success.

## Applying after verification

Use a fresh preview, its exact order, bank reference and approval hash, and the
SAME `--vpbank-minute-time` flag. It is bound into the approval hash and audit.
Do not reuse an old approval from exact mode or from another data snapshot.

```powershell
npm run payments:reconcile -- --transaction YOUR_SEPAY_ID --order ZCA_FULL_CODE --approve FRESH_PREVIEW_HASH --bank-reference EXACT_REFERENCE --vpbank-minute-time --bank-verified --not-previously-credited --note "Bank record and minute precision verified; no previous credit or refund" --apply
```

The existing tool checks ADMIN_USER_ID, makes a private backup and revalidates
under the data lock. It records the selected time interpretation in the audit.
It preserves raw bank data, original transactionDate, fingerprint and receivedAt.
Do not modify timestamps in JSON or delete dedupe receipts to force approval.
If data changed, run a fresh preview instead of bypassing REVIEW_CHANGED.
Already-paid receipts remain paid and cannot be credited twice.

No public HTTP route exposes this option. The webhook handler constructs its
confirmation arguments explicitly and never accepts reviewTime from bank JSON.
Restart payments:local after updating code for future requests; keep cloudflared
running. The one-shot CLI loads new code without restarting the main backend.
No Flutter build is needed. This only updates code, not existing payment statuses.

## Verification scope

45 focused tests passed on Node 22 in a Linux sandbox using synthetic, in-memory
transactional fixtures and the actual payment modules. They cover exact default
behavior, same-minute limits, unchanged evidence, operator confirmations, stale
approval, failed commits, duplicate handling and HMAC checks. The full payment
suite, Windows CLI I/O and real SePay/VPBank transfers were not rerun in this step.
