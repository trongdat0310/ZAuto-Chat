# SePay VPBank payment integration

Configure backend environment:
- `SEPAY_BANK_ACCOUNT=0945785631` (verify this is the actual linked VPBank account number)
- `SEPAY_WEBHOOK_SECRET=<long-random-secret>` (same HMAC-SHA256 secret entered in SePay)

Webhook: `POST https://YOUR_BACKEND/api/payments/sepay/webhook`. Configure **Money in**, linked VPBank account, **HMAC-SHA256**. Raw request body is signed as `timestamp.raw_body` and checked with a 5-minute clock tolerance.

Order API: `POST /api/payments/orders` JSON `{"phone":"09...","planId":"monthly30"}`; response includes `order.id`, exact amount, expiry, and transfer content. Public `GET /api/payments/orders/:id` returns only payment status.

**Important:** Deploy on a single host with persistent `data/` storage. Orders and subscriptions are written atomically in the same JSON store. Multi-instance or ephemeral disk requires migration to a transactional database. Prices are server-controlled in `payment-routes.js`; update these when pricing changes. Only unique exact transfer codes within 30 minutes and exact amount/account are auto-applied; unmatched transfers need manual reconciliation. This does not implement automated refund or polling SePay reconciliation.

Never configure an unauthenticated SePay webhook. Keep secrets out of git. Test with a real order and SePay test delivery before accepting customers.
