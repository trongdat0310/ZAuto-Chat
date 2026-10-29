import crypto from "node:crypto";
import { paymentError, sha256, isOrderId, sameBank, validateTransaction,
  extractOrderCode, transactionTime, transactionFingerprint } from "./payment-security.js";

// These methods run through the SUBSCRIPTION store's lock + fsync + atomic rename.
// Paid order, transaction receipt and entitlement are committed together, never
// as two separate writes. Existing usage, admin idempotency and logs are preserved.
export function createPaymentOperations({ read, change, planById, validate, isActive,
  dateVN, endOfDayVN, monthAfterVN, renewMain, clock }) {
  const assertNow = now => { if (!(now instanceof Date) || !Number.isFinite(+now)) throw paymentError("INVALID_TIME"); };
  return {
    createPaymentOrder({ userId, planId, amount, accountNumber, gateway = "VPBank", subAccount = "",
      requestId, ttlMinutes = 30, now = clock() }) {
      validate(userId); assertNow(now);
      const plan = planById(planId);
      if (!plan || !Number.isSafeInteger(amount) || amount <= 0 ||
          typeof accountNumber !== "string" || !/^\d{6,30}$/.test(accountNumber) ||
          gateway !== "VPBank" || typeof subAccount !== "string" || subAccount.length > 128 ||
          !Number.isInteger(ttlMinutes) || ttlMinutes < 5 || ttlMinutes > 120) throw paymentError("INVALID_PAYMENT_PLAN");
      if (requestId !== undefined && (typeof requestId !== "string" || !/^[A-Za-z0-9_-]{16,128}$/.test(requestId))) throw paymentError("INVALID_REQUEST_ID");
      return change(data => {
        const commands = data.paymentOrderRequests ||= {};
        const requestKey = requestId ? sha256(JSON.stringify([userId, requestId])) : null;
        const fingerprint = sha256(JSON.stringify([planId, accountNumber, gateway, subAccount]));
        if (requestKey && commands[requestKey]) {
          const previous = commands[requestKey];
          if (previous.fingerprint !== fingerprint) throw paymentError("REQUEST_ID_CONFLICT", "Yeu cau da duoc dung cho goi khac.", 409);
          const order = data.paymentOrders?.[previous.orderId];
          if (!order) throw paymentError("PAYMENT_STORE_INVALID", "Du lieu don khong hop le.", 503);
          return structuredClone(order);
        }
        const main = data.subscriptions[userId]?.main;
        if (!plan.addon && isActive(main, now) && main.planId !== planId) {
          throw paymentError("ACTIVE_PLAN_CONFLICT", "Tai khoan dang dung goi khac. Hay gia han dung goi hoac lien he Admin de doi goi.", 409);
        }
        if (plan.addon && isActive(main, now) && main.planId === "unlimited") {
          throw paymentError("UNLIMITED_ACTIVE", "Goi hien tai khong gioi han; khong can mua them luot.", 409);
        }
        const orders = data.paymentOrders ||= {};
        const mine = Object.values(orders).filter(o => o.userId === userId);
        if (mine.filter(o => o.status === "pending" && Date.parse(o.expiresAt) > +now).length >= 5 ||
            mine.filter(o => Date.parse(o.createdAt) > +now - 86400000).length >= 30) {
          throw paymentError("TOO_MANY_ORDERS", "Ban da tao nhieu don. Hay dung don dang cho hoac thu lai sau.", 429);
        }
        let id;
        do { id = "ZCA" + crypto.randomBytes(9).toString("hex").toUpperCase(); } while (orders[id]);
        const expires = Math.min(+now + ttlMinutes * 60000, plan.addon ? +endOfDayVN(now) : Infinity);
        if (expires - +now < 60000) throw paymentError("ADDON_DAY_ENDING", "Sap het ngay. Hay tao goi ngay sau 00:00 gio Viet Nam.", 409);
        const order = { id, version: 2, userId, planId, amount, months: 1, accountNumber, gateway, subAccount,
          action: plan.addon ? "addon" : isActive(main, now) ? "renew" : "assign",
          status: "pending", createdAt: now.toISOString(), expiresAt: new Date(expires).toISOString() };
        orders[id] = order;
        if (requestKey) commands[requestKey] = { orderId: id, fingerprint };
        return structuredClone(order);
      });
    },
    getPaymentOrder(id) {
      if (!isOrderId(id)) throw paymentError("INVALID_PAYMENT_ORDER");
      return read().paymentOrders?.[id] || null;
    },
    confirmPayment({ transaction: tx, accountNumber, gateway = "VPBank", subAccount = "", rawBody,
      userExists = () => true, now = clock() }) {
      assertNow(now); validateTransaction(tx);
      if (typeof accountNumber !== "string" || !/^\d{6,30}$/.test(accountNumber) || gateway !== "VPBank") throw paymentError("INVALID_PAYMENT_CONFIG", "Sai cau hinh nhan tien.", 503);
      const bankTime = transactionTime(tx.transactionDate);
      const fingerprint = transactionFingerprint(tx);
      return change(data => {
        const transactions = data.paymentTransactions ||= {};
        const key = "sepay:" + tx.id;
        const prior = transactions[key];
        if (prior) {
          if (prior.fingerprint && prior.fingerprint !== fingerprint) {
            const incident = sha256(fingerprint);
            prior.conflicts ||= [];
            if (!prior.conflicts.includes(incident) && prior.conflicts.length < 10) prior.conflicts.push(incident);
            return { duplicate: true, status: "review", reason: "TRANSACTION_CHANGED" };
          }
          return { duplicate: true, status: prior.status, reason: prior.reason,
            userId: prior.status === "paid" ? prior.userId : undefined };
        }
        const code = extractOrderCode(tx);
        const order = code ? data.paymentOrders?.[code] : null;
        const receipt = { status: "review", reason: null, transactionId: String(tx.id), orderId: order?.id || null,
          receivedAt: now.toISOString(), fingerprint, payload: structuredClone(tx),
          rawBody: typeof rawBody === "string" ? rawBody : JSON.stringify(tx) };
        transactions[key] = receipt;
        const reject = (reason, status = "review") => {
          receipt.reason = reason; receipt.status = status;
          if (order && order.status === "pending" && status === "review") {
            order.lastIssue = { reason, transactionId: String(tx.id), at: now.toISOString() };
          }
          return { duplicate: false, status, reason, orderId: order?.id || null };
        };
        if (tx.transferType !== "in") return reject("MONEY_OUT", "ignored");
        if (!sameBank(tx.gateway, gateway) || tx.accountNumber !== accountNumber ||
            (subAccount && tx.subAccount !== subAccount)) return reject("WRONG_RECEIVER", "ignored");
        const refs = data.paymentReferences ||= {};
        const reference = tx.referenceCode?.trim();
        const refKey = reference ? sha256(JSON.stringify([gateway, accountNumber, "in", reference])) : null;
        if (refKey && refs[refKey]) return reject("DUPLICATE_BANK_REFERENCE");
        if (refKey) refs[refKey] = key;
        if (!order) return reject(code ? "ORDER_NOT_FOUND" : "MISSING_OR_AMBIGUOUS_CODE");
        if (order.status !== "pending") return reject("ORDER_ALREADY_PAID");
        // Do not auto-apply old orders lacking a snapshot of the receiving bank.
        if (order.version !== 2 || order.accountNumber !== accountNumber ||
            order.gateway !== gateway || order.subAccount !== subAccount) return reject("ORDER_CONFIG_CHANGED");
        if (tx.transferAmount !== order.amount) return reject("AMOUNT_MISMATCH");
        if (bankTime < Math.floor(Date.parse(order.createdAt) / 1000) * 1000 ||
            bankTime > Date.parse(order.expiresAt) || bankTime > +now + 300000) return reject("TRANSFER_OUTSIDE_WINDOW");
        if (!userExists(order.userId)) return reject("ACCOUNT_NOT_FOUND");
        const plan = planById(order.planId);
        if (!plan) return reject("PLAN_UNAVAILABLE");
        if (plan.addon && dateVN(new Date(bankTime)) !== dateVN(now)) return reject("ADDON_DAY_CHANGED");
        const record = data.subscriptions[order.userId] ||= { main: null, addons: [] };
        if (!plan.addon && isActive(record.main, now) && record.main.planId !== plan.id) return reject("ACTIVE_PLAN_CHANGED");
        if (plan.addon && isActive(record.main, now) && record.main.planId === "unlimited") return reject("UNLIMITED_ACTIVE");
        const previous = record.main;
        let item, action;
        if (!plan.addon && isActive(previous, now)) {
          item = renewMain(previous, 1, now, monthAfterVN, endOfDayVN); action = "renew";
          record.main = item;
        } else {
          item = { id: crypto.randomUUID(), planId: plan.id, period: plan.period, startsAt: now.toISOString(),
            endsAt: endOfDayVN(plan.addon ? now : monthAfterVN(now, 1)).toISOString() };
          action = plan.addon ? "addon" : "assign";
          if (plan.addon) (record.addons ||= []).push(item); else record.main = item;
        }
        Object.assign(order, { status: "paid", paidAt: now.toISOString(), transactionId: String(tx.id),
          action, entitlementId: item.id, entitlementEndsAt: item.endsAt });
        delete order.lastIssue;
        Object.assign(receipt, { status: "paid", reason: null, userId: order.userId, action });
        data.logs.push({ id: crypto.randomUUID(), at: now.toISOString(), actorId: "sepay", userId: order.userId,
          action: "payment_" + action, item, previous, orderId: order.id, transactionId: String(tx.id) });
        return { duplicate: false, status: "paid", orderId: order.id, userId: order.userId, action };
      });
    },
    getPaymentTransactions({ limit = 100 } = {}) {
      if (!Number.isInteger(limit) || limit < 1 || limit > 500) throw paymentError("INVALID_LIMIT");
      return Object.values(read().paymentTransactions || {}).slice(-limit).reverse();
    },
  };
}
