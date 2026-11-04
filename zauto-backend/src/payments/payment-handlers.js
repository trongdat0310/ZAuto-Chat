import { paymentConfig } from "./payment-config.js";
import { paymentError, verifySePaySignature, validateTransaction, checkoutToken,
  verifyCheckoutToken } from "./payment-security.js";

function publicOrder(order, now) {
  return { id: order.id, planId: order.planId, amount: order.amount, action: order.action,
    status: order.status === "pending" && now > Date.parse(order.expiresAt) ? "expired" : order.status,
    expiresAt: order.expiresAt, paidAt: order.paidAt || null,
    entitlementEndsAt: order.entitlementEndsAt || null, reviewRequired: Boolean(order.lastIssue) };
}
function normalizePhone(value) {
  if (typeof value !== "string") return "";
  let phone = value.trim().replace(/[ .()-]/g, "");
  if (/^\+?84\d{9}$/.test(phone)) phone = "0" + phone.replace(/^\+?84/, "");
  return phone;
}

// Shared between the main Express backend and the narrow local payment gateway.
// No network send, password, role changes, or client-side paid flag is trusted.
export function createPaymentHandlers({ store, findUserByPhone, findUserById,
  notify = () => {}, env = process.env, clock = () => Date.now(), logger = console }) {
  let minuteStart = clock(), createsThisMinute = 0;
  function sendError(res, error) {
    const status = [400, 401, 403, 404, 409, 429, 503].includes(error.status) ? error.status : 503;
    if (status === 503) logger.error?.("[PAYMENTS]", error.code || error.name || "PROCESSING_FAILED");
    return res.status(status).json({ success: false, code: error.code || "PAYMENT_ERROR",
      error: status === 503 && !String(error.code).startsWith("PAYMENTS_")
        ? "Thanh toan tam thoi chua xu ly duoc. Vui long thu lai." : error.message });
  }
  return {
    catalog(req, res) {
      try {
        const config = paymentConfig(env);
        return res.json({ success: true, plans: store.listPlans().map(plan => ({ ...plan,
          price: config.prices[plan.id] })), ttlMinutes: config.ttlMinutes });
      } catch (error) { return sendError(res, error); }
    },
    createOrder(req, res) {
      try {
        const config = paymentConfig(env);
        const now = clock();
        if (now - minuteStart >= 60000) { minuteStart = now; createsThisMinute = 0; }
        if (++createsThisMinute > 60) throw paymentError("ORDER_RATE_LIMIT", "Vui long cho mot phut roi thu lai.", 429);
        const body = req.body;
        if (!body || Array.isArray(body) || Object.keys(body).some(k => !["phone", "planId", "requestId"].includes(k))) {
          throw paymentError("INVALID_ORDER_FIELDS", "Chi gui phone, planId va requestId; gia duoc tinh tai may chu.");
        }
        const phone = normalizePhone(body.phone);
        if (!/^0\d{9}$/.test(phone) || typeof body.planId !== "string" || !Object.hasOwn(config.prices, body.planId)) throw paymentError("INVALID_ORDER", "So dien thoai hoac goi khong hop le.");
        const user = findUserByPhone(phone);
        if (!user) throw paymentError("ACCOUNT_NOT_FOUND", "So dien thoai chua dang ky ZAutoChat.", 404);
        const order = store.createPaymentOrder({ userId: user.id, planId: body.planId,
          amount: config.prices[body.planId], accountNumber: config.accountNumber, gateway: config.gateway,
          subAccount: config.subAccount, requestId: body.requestId, ttlMinutes: config.ttlMinutes, now: new Date(now) });
        const qr = new URL("https://vietqr.app/img");
        qr.search = new URLSearchParams({ acc: config.subAccount || config.accountNumber, bank: "VPBank",
          amount: String(order.amount), des: order.id }).toString();
        res.set?.("Cache-Control", "no-store");
        return res.status(201).json({ success: true, order: publicOrder(order, now),
          checkoutToken: checkoutToken(config.secret, order.id), bank: config.gateway,
          accountNumber: config.subAccount || config.accountNumber, accountName: config.accountName,
          transferContent: order.id, qrUrl: qr.href });
      } catch (error) { return sendError(res, error); }
    },
    orderStatus(req, res) {
      try {
        const config = paymentConfig(env);
        const id = req.params?.id;
        const token = req.get("X-Checkout-Token");
        if (!verifyCheckoutToken(config.secret, id, token)) throw paymentError("INVALID_CHECKOUT_TOKEN", "Khong co quyen xem don nay.", 403);
        const order = store.getPaymentOrder(id);
        if (!order) throw paymentError("ORDER_NOT_FOUND", "Khong tim thay don hang.", 404);
        res.set?.("Cache-Control", "no-store");
        return res.json({ success: true, order: publicOrder(order, clock()) });
      } catch (error) { return sendError(res, error); }
    },
    webhook(req, res) {
      try {
        const config = paymentConfig(env);
        verifySePaySignature(req.body, req.headers, config.secret, clock());
        let transaction;
        try { transaction = JSON.parse(req.body.toString("utf8")); }
        catch { throw paymentError("INVALID_JSON", "JSON khong hop le."); }
        validateTransaction(transaction);
        const result = store.confirmPayment({ transaction, rawBody: req.body.toString("utf8"),
          accountNumber: config.accountNumber, gateway: config.gateway, subAccount: config.subAccount,
          now: new Date(clock()), userExists: id => Boolean(findUserById(id)) });
        if (result.userId) {
          try { notify(result.userId); } catch { /* Payment is already committed. Do not cause another charge. */ }
        }
        if (!result.duplicate || result.status === "review") {
          logger.info?.("[SEPAY]", transaction.id, result.status, result.reason || "", result.orderId || "");
        }
        // Acknowledges durable RECEIPT, not necessarily a paid order. Unmatched
        // money is stored for review, so retries must not keep applying it.
        return res.status(200).json({ success: true });
      } catch (error) { return sendError(res, error); }
    },
  };
}
