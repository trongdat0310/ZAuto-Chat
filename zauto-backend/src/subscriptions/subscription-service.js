import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { adminCommand, renewMain, subscriptionRevision } from "./subscription-admin-commands.js";

export const PLANS = Object.freeze([
  { id: "monthly30", name: "30 lượt/tháng", limit: 30, period: "month", addon: false },
  { id: "daily15", name: "15 lượt/ngày", limit: 15, period: "day", addon: false },
  { id: "daily30", name: "30 lượt/ngày", limit: 30, period: "day", addon: false },
  { id: "daily55", name: "55 lượt/ngày", limit: 55, period: "day", addon: false },
  { id: "unlimited", name: "Unlimited", limit: null, period: "day", addon: false },
  { id: "extra10", name: "Thêm 10 lượt/ngày", limit: 10, period: "day", addon: true },
  { id: "extra30", name: "Thêm 30 lượt/ngày", limit: 30, period: "day", addon: true },
].map(Object.freeze));
export const FEATURES = Object.freeze(["trip_screen_accept", "chat_accept", "auto_accept"]);
const planById = id => PLANS.find(plan => plan.id === id);
const OFFSET = 7 * 60 * 60 * 1000;
export const dateVN = date => new Date(+date + OFFSET).toISOString().slice(0, 10);
export function monthAfterVN(date, months) {
  const d = new Date(+date + OFFSET), day = d.getUTCDate();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() + months);
  const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  d.setUTCDate(Math.min(day, last));
  return new Date(+d - OFFSET);
}
const endOfDay = now => new Date(Date.parse(`${dateVN(now)}T00:00:00+07:00`) + 86400000);
const isActive = (item, now) => item && Date.parse(item.startsAt) <= +now && +now < Date.parse(item.endsAt);
const pending = op => ["reserved", "sending", "uncertain"].includes(op.status);
export function subscriptionError(code, message = code, status = 400) {
  return Object.assign(new Error(message), { code, status });
}
function validKey(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value) ||
      ["__proto__", "constructor", "prototype"].includes(value)) {
    throw subscriptionError("INVALID_ID");
  }
}
function validate(userId, feature) {
  validKey(userId);
  if (feature !== undefined && !FEATURES.includes(feature)) throw subscriptionError("INVALID_FEATURE");
}
const empty = () => ({ version: 2, subscriptions: {}, usage: {}, operations: {}, logs: [] });

// The JSON store is for one host/local disk. Each short mutation owns an exclusive
// lock; NEVER hold this lock across a Zalo/network await. Use a DB for multi-host deployments.
export function createSubscriptionService({ file, clock = () => new Date() }) {
  function read() {
    let data;
    try { data = JSON.parse(fs.readFileSync(file, "utf8")); }
    catch (e) { if (e.code === "ENOENT") return empty(); throw e; }
    if (!data || typeof data !== "object" || !data.subscriptions || !data.usage || !Array.isArray(data.logs)) {
      throw subscriptionError("SUBSCRIPTION_STORE_INVALID", "Du lieu goi khong hop le.", 503);
    }
    if (data.version === 2 && data.operations) return data;
    if (data.version !== undefined) throw subscriptionError("SUBSCRIPTION_STORE_VERSION", "Unsupported store version", 503);
    // Keep v1 for audit/backup; migrate its counters conservatively to the main bucket.
    const migrated = { ...empty(), subscriptions: data.subscriptions, logs: data.logs, legacyUsage: data.usage };
    for (const [userId, features] of Object.entries(data.usage)) {
      validKey(userId);
      const main = data.subscriptions[userId]?.main;
      if (!main) continue;
      for (const feature of FEATURES) {
        for (const [period, count] of Object.entries(features[feature] || {})) {
          const key = main.period === "month" ? `${main.id}/month/0` : `${main.id}/day/${period}`;
          (migrated.usage[userId] ||= {})[feature] ||= {};
          migrated.usage[userId][feature][key] = count;
        }
      }
    }
    return migrated;
  }
  function change(fn) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    let lock;
    try { lock = fs.openSync(`${file}.lock`, "wx", 0o600); }
    catch (e) {
      if (e.code === "EEXIST") throw subscriptionError("SUBSCRIPTION_BUSY", "He thong dang cap nhat luot. Vui long thu lai.", 503);
      throw e;
    }
    const temp = `${file}.${crypto.randomUUID()}.tmp`;
    try {
      fs.writeFileSync(lock, JSON.stringify({ pid: process.pid, createdAt: clock().toISOString() }));
      const data = read();
      const result = fn(data);
      if (data.legacyUsage && fs.existsSync(file)) {
        try { fs.copyFileSync(file, `${file}.v1.bak`, fs.constants.COPYFILE_EXCL); }
        catch (e) { if (e.code !== "EEXIST") throw e; }
      }
      const fd = fs.openSync(temp, "wx", 0o600);
      try { fs.writeFileSync(fd, JSON.stringify(data, null, 2)); fs.fsyncSync(fd); }
      finally { fs.closeSync(fd); }
      fs.renameSync(temp, file);
      return result;
    } finally {
      fs.rmSync(temp, { force: true });
      fs.closeSync(lock);
      fs.unlinkSync(`${file}.lock`);
    }
  }
  function buckets(data, userId, now) {
    const record = data.subscriptions[userId];
    const hasMain = isActive(record?.main, now);
    const main = hasMain ? record.main : null;
    if (!hasMain && !(record?.addons || []).some(a => isActive(a, now))) return [];
    const plan = main ? planById(main.planId) : null;
    if (main && (!plan || plan.addon)) throw subscriptionError("SUBSCRIPTION_STORE_INVALID", "Invalid main plan", 503);
    let period = main ? `${main.id}/day/${dateVN(now)}` : '';
    let endsAt = main ? new Date(Math.min(+endOfDay(now), Date.parse(main.endsAt))).toISOString() : '';
    if (main && plan.period === "month") {
      const start = new Date(main.startsAt);
      let i = 0;
      while (monthAfterVN(start, i + 1) <= now) i++;
      period = `${main.id}/month/${i}`;
      endsAt = new Date(Math.min(+monthAfterVN(start, i + 1), Date.parse(main.endsAt))).toISOString();
    }
    const result = main ? [{ key: period, limit: plan.limit, endsAt, planId: plan.id, addon: false }] : [];
    if (!main || plan.limit !== null) {
      for (const addon of record.addons || []) {
        if (!isActive(addon, now)) continue;
        const p = planById(addon.planId);
        if (!p?.addon) throw subscriptionError("SUBSCRIPTION_STORE_INVALID", "Invalid add-on", 503);
        result.push({ key: `${addon.id}/addon`, limit: p.limit, endsAt: addon.endsAt, planId: p.id, addon: true });
      }
    }
    // Use expiring add-ons first; their consumption must not eat monthly quota tomorrow.
    return result.sort((a, b) => Number(b.addon) - Number(a.addon) || a.endsAt.localeCompare(b.endsAt));
  }
  function status(data, userId, feature, now) {
    const rows = buckets(data, userId, now).map(bucket => {
      const used = data.usage[userId]?.[feature]?.[bucket.key] || 0;
      if (!Number.isSafeInteger(used) || used < 0) throw subscriptionError("SUBSCRIPTION_STORE_INVALID", "Invalid usage count", 503);
      const reserved = Object.values(data.operations[userId] || {}).filter(op =>
        op.feature === feature && op.bucket === bucket.key && pending(op)).length;
      return { ...bucket, used, reserved, remaining: bucket.limit === null ? null : Math.max(0, bucket.limit - used - reserved) };
    });
    const unlimited = rows.some(b => b.limit === null);
    const remaining = unlimited ? null : rows.reduce((sum, b) => sum + b.remaining, 0);
    return { feature, planId: rows.find(b => !b.addon)?.planId || null,
      used: rows.reduce((n, b) => n + b.used, 0), reserved: rows.reduce((n, b) => n + b.reserved, 0),
      limit: unlimited ? null : rows.reduce((n, b) => n + b.limit, 0), remaining,
      allowed: unlimited || remaining > 0, buckets: rows };
  }
  function audit(data, record) { data.logs.push({ id: crypto.randomUUID(), at: clock().toISOString(), ...record }); }
  const service = {
    listPlans: () => PLANS,
    getUsageStatus(userId, feature, now = clock()) { validate(userId, feature); return status(read(), userId, feature, now); },
    getSubscription(userId, now = clock()) {
      validate(userId);
      const data = read(), record = data.subscriptions[userId] || { main: null, addons: [] };
      return { revision: subscriptionRevision(record), serverNow: now.toISOString(), timeZone: "Asia/Ho_Chi_Minh",
        main: isActive(record.main, now) ? record.main : null,
        lastMain: record.main, addons: (record.addons || []).filter(a => isActive(a, now)),
        features: FEATURES.map(feature => status(data, userId, feature, now)) };
    },
    assignPlan({ userId, planId, months = 1, actorId, requestId, expectedRevision, note = "", now = clock() }) {
      validate(userId); validKey(actorId);
      const plan = planById(planId);
      if (!plan) throw subscriptionError("INVALID_PLAN");
      if (!plan.addon && (!Number.isInteger(months) || months < 1 || months > 24)) throw subscriptionError("INVALID_DURATION");
      return change(data => adminCommand(data, { actorId, userId, requestId, expectedRevision },
        { action: "assign", planId, months, note }, () => {
        const record = data.subscriptions[userId] ||= { main: null, addons: [] };
        const item = { id: crypto.randomUUID(), planId, period: plan.period, startsAt: now.toISOString(),
          endsAt: (plan.addon ? endOfDay(now) : monthAfterVN(now, months)).toISOString() };
        const previous = record.main;
        if (plan.addon) record.addons.push(item); else record.main = item;
        // Never discard historical counters or accepted-target deduplication on reassignment.
        audit(data, { actorId, userId, action: "assign", item, previous, requestId, note });
        return item;
      }));
    },
    revokePlan({ userId, actorId, requestId, expectedRevision, note = "", now = clock() }) {
      validate(userId); validKey(actorId);
      return change(data => adminCommand(data, { actorId, userId, requestId, expectedRevision },
        { action: "revoke", note }, () => {
        const previous = data.subscriptions[userId];
        data.subscriptions[userId] = { main: null, addons: [] };
        audit(data, { actorId, userId, action: "revoke", previous, requestId, note, at: now.toISOString() });
        return { revoked: true };
      }));
    },
    renewPlan({ userId, months = 1, actorId, requestId, expectedRevision, note = "", now = clock() }) {
      validate(userId); validKey(actorId);
      return change(data => adminCommand(data, { actorId, userId, requestId, expectedRevision },
        { action: "renew", months, note }, () => {
          const record = data.subscriptions[userId];
          const previous = record?.main;
          if (previous && (!planById(previous.planId) || planById(previous.planId).addon)) throw subscriptionError("INVALID_PLAN");
          const item = renewMain(previous, months, now, monthAfterVN);
          // Expired renewals start a new cycle and cannot revive old add-ons.
          if (!isActive(previous, now)) record.addons = [];
          record.main = item;
          audit(data, { actorId, userId, action: "renew", previous, item, months, requestId, note });
          return item;
        }));
    },
    reserveUsage(userId, feature, targetKey, now = clock(), context = null) {
      validate(userId, feature); validKey(targetKey);
      return change(data => {
        const operations = data.operations[userId] ||= {};
        const previous = operations[targetKey];
        if (previous?.status === "succeeded") return { duplicate: true, operation: previous };
        if (previous && pending(previous)) {
          throw subscriptionError(previous.status === "uncertain" ? "ACCEPT_OUTCOME_UNKNOWN" : "ACCEPT_IN_PROGRESS",
            previous.status === "uncertain" ? "Chua xac dinh ket qua gui. Khong gui lai de tranh trung; lien he Admin kiem tra." : "Cuoc dang duoc nhan. Vui long cho.", 409);
        }
        const quota = status(data, userId, feature, now);
        const bucket = quota.buckets.find(b => b.remaining === null || b.remaining > 0);
        if (!bucket) throw subscriptionError("SUBSCRIPTION_LIMIT_REACHED", "Da het luot nhan cuoc hoac goi da het han.", 403);
        const operation = { id: crypto.randomUUID(), targetKey, feature, bucket: bucket.key,
          status: "reserved", context, createdAt: now.toISOString() };
        operations[targetKey] = operation;
        return { duplicate: false, operation };
      });
    },
    transition(userId, operation, next, result = null) {
      validate(userId);
      return change(data => {
        const current = data.operations[userId]?.[operation.targetKey];
        if (!current || current.id !== operation.id || !pending(current)) throw subscriptionError("ACCEPT_RESERVATION_CHANGED", "Accept reservation changed", 409);
        if (!["sending", "succeeded", "failed", "uncertain"].includes(next)) throw subscriptionError("INVALID_TRANSITION");
        if (next === "succeeded") {
          const counts = ((data.usage[userId] ||= {})[current.feature] ||= {});
          counts[current.bucket] = (counts[current.bucket] || 0) + 1;
          current.result = result;
        }
        current.status = next;
        current.updatedAt = clock().toISOString();
        return current;
      });
    },
    getAuditLogs(userId) {
      if (userId !== undefined) validate(userId);
      return read().logs.filter(log => userId === undefined || log.userId === userId).slice(-200).reverse();
    },
    getAcceptedOperations(userId) {
      validate(userId);
      return Object.values(read().operations[userId] || {}).filter(op => op.status === "succeeded")
        .sort((a, b) => (b.result?.acceptedAt || b.updatedAt || b.createdAt).localeCompare(a.result?.acceptedAt || a.updatedAt || a.createdAt))
        .slice(0, 500);
    },
    getPendingOperations(userId) {
      validate(userId);
      return Object.values(read().operations[userId] || {}).filter(pending);
    },
    resolveUncertain({ userId, targetKey, outcome, actorId, note, requestId, expectedRevision }) {
      validate(userId); validKey(actorId); validKey(targetKey);
      if (!["succeeded", "failed"].includes(outcome) || typeof note !== "string" || note.trim().length < 5 || note.length > 500) {
        throw subscriptionError("INVALID_RECONCILIATION");
      }
      return change(data => adminCommand(data, { actorId, userId, requestId, expectedRevision },
        { action: "reconcile", targetKey, outcome, note }, () => {
        const op = data.operations[userId]?.[targetKey];
        // Never free an actively sending reservation through this API.
        if (op?.status !== "uncertain") throw subscriptionError("OPERATION_NOT_UNCERTAIN", "Operation is not awaiting reconciliation", 409);
        if (outcome === "succeeded") {
          const counts = ((data.usage[userId] ||= {})[op.feature] ||= {});
          counts[op.bucket] = (counts[op.bucket] || 0) + 1;
          op.result = { ...op.context, reconciled: true, acceptedAt: clock().toISOString() };
        }
        op.status = outcome;
        audit(data, { actorId, userId, action: "reconcile", targetKey, outcome, requestId, note: note.trim() });
        return op;
      }));
    },
  };
  // Compatibility for internal callers only. External side effects MUST use runMeteredAcceptance.
  service.consumeUsage = (userId, feature, requestId, now = clock()) => {
    const reservation = service.reserveUsage(userId, feature, requestId, now);
    if (!reservation.duplicate) service.transition(userId, reservation.operation, "succeeded", {});
    return { ...service.getUsageStatus(userId, feature, now), duplicate: reservation.duplicate, consumed: !reservation.duplicate };
  };
  return service;
}

export const subscriptionService = createSubscriptionService({
  file: process.env.SUBSCRIPTIONS_DATA_FILE || fileURLToPath(new URL("../../data/subscriptions.json", import.meta.url)),
});
export const { listPlans, getUsageStatus, getSubscription, assignPlan, renewPlan, revokePlan, consumeUsage, getAuditLogs } = subscriptionService;
