import { Router } from "express";
import crypto from "node:crypto";
import { subscriptionService as store } from "../subscriptions/subscription-service.js";
import { findUserByPhone } from "../users/user-store.js";
import { notifySubscriptionChanged } from "../subscriptions/acceptance-history-service.js";

export const paymentRouter = Router();
const prices = Object.freeze({ monthly30: 139000, daily15: 299000, daily30: 499000, daily55: 899000,
  unlimited: 9999999, extra10: 20000, extra30: 50000 });
const bankAccount = () => String(process.env.SEPAY_BANK_ACCOUNT || "").trim();
const fail = (res, status, message) => res.status(status).json({ success: false, error: message });

paymentRouter.post("/orders", (req, res) => {
  try {
    if (!bankAccount()) return fail(res, 503, "Chua cau hinh tai khoan nhan thanh toan.");
    const phone = String(req.body?.phone || "").trim();
    const planId = req.body?.planId;
    if (!/^0[0-9]{9}$/.test(phone) || !Object.hasOwn(prices, planId)) return fail(res, 400, "Thong tin goi hoac so dien thoai khong hop le.");
    const user = findUserByPhone(phone);
    if (!user) return fail(res, 404, "So dien thoai chua dang ky ZAutoChat.");
    const order = store.createPaymentOrder({ userId: user.id, planId, amount: prices[planId] });
    return res.status(201).json({ success: true, order: { id: order.id, planId, amount: order.amount,
      status: order.status, expiresAt: order.expiresAt }, bank: "VPBank", accountNumber: bankAccount(),
      accountName: "PHI TRONG DAT", transferContent: order.id });
  } catch (error) { console.error("[PAYMENTS] order", error); return fail(res, 500, "Khong the tao don hang."); }
});
paymentRouter.get("/orders/:id", (req, res) => {
  try {
    const order = store.getPaymentOrder(req.params.id);
    if (!order) return fail(res, 404, "Khong tim thay don hang.");
    return res.json({ success: true, order: { id: order.id, status: order.status, expiresAt: order.expiresAt } });
  } catch { return fail(res, 400, "Ma don hang khong hop le."); }
});

export function sepayWebhook(req, res) {
  const secret = process.env.SEPAY_WEBHOOK_SECRET;
  if (!secret || !bankAccount()) return fail(res, 503, "Webhook chua duoc cau hinh.");
  const timestamp = req.get("X-SePay-Timestamp") || "";
  const signature = req.get("X-SePay-Signature") || "";
  const now = Math.floor(Date.now() / 1000);
  if (!/^\d{10}$/.test(timestamp) || Math.abs(now - Number(timestamp)) > 300 ||
      !/^sha256=[a-f0-9]{64}$/i.test(signature) || !Buffer.isBuffer(req.body)) {
    return fail(res, 401, "Invalid signature.");
  }
  const expected = crypto.createHmac("sha256", secret).update(timestamp + ".").update(req.body).digest();
  const supplied = Buffer.from(signature.slice(7), "hex");
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) return fail(res, 401, "Invalid signature.");
  let tx;
  try { tx = JSON.parse(req.body.toString("utf8")); }
  catch { return fail(res, 400, "Invalid JSON."); }
  if (!tx || !Number.isSafeInteger(tx.id) || tx.id < 1 || typeof tx.content !== "string" ||
      typeof tx.accountNumber !== "string" || !Number.isSafeInteger(tx.transferAmount) ||
      tx.transferAmount <= 0 || !["in", "out"].includes(tx.transferType)) return fail(res, 400, "Invalid transaction.");
  try {
    const result = store.confirmPayment({ transaction: tx, accountNumber: bankAccount() });
    if (result.userId) notifySubscriptionChanged(result.userId);
    return res.status(200).json({ success: true });
  } catch (error) { console.error("[SEPAY] webhook processing", error); return fail(res, 503, "Processing failed."); }
}
