import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

export const PLANS = Object.freeze([
  { id: "monthly30", name: "30 lượt/tháng", limit: 30, period: "month", addon: false },
  { id: "daily15", name: "15 lượt/ngày", limit: 15, period: "day", addon: false },
  { id: "daily30", name: "30 lượt/ngày", limit: 30, period: "day", addon: false },
  { id: "daily55", name: "55 lượt/ngày", limit: 55, period: "day", addon: false },
  { id: "unlimited", name: "Unlimited", limit: null, period: "day", addon: false },
  { id: "extra10", name: "Thêm 10 lượt/ngày", limit: 10, period: "day", addon: true },
  { id: "extra30", name: "Thêm 30 lượt/ngày", limit: 30, period: "day", addon: true },
]);

const file = process.env.SUBSCRIPTIONS_DATA_FILE || path.resolve(process.cwd(), "data/subscriptions.json");
const planById = id => PLANS.find(plan => plan.id === id);
const dateVN = date => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh", year: "numeric", month: "2-digit", day: "2-digit" }).format(date);
const monthAfter = (date, months) => { const d = new Date(date); const day = d.getUTCDate(); d.setUTCDate(1); d.setUTCMonth(d.getUTCMonth() + months); const last = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate(); d.setUTCDate(Math.min(day, last)); return d; };
function endOfVietnamDay(now) { const [y,m,d] = dateVN(now).split("-").map(Number); return new Date(Date.UTC(y,m-1,d+1, -7)); }
function read() {
  try { const value = JSON.parse(fs.readFileSync(file, "utf8")); return { subscriptions: value.subscriptions || {}, usage: value.usage || {}, logs: value.logs || [] }; }
  catch (error) { if (error.code === "ENOENT") return { subscriptions: {}, usage: {}, logs: [] }; throw error; }
}
function write(data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temp = file + "." + process.pid + "." + crypto.randomUUID() + ".tmp";
  fs.writeFileSync(temp, JSON.stringify(data, null, 2), { mode: 0o600 });
  fs.renameSync(temp, file);
}
function active(item, now) { return item && Date.parse(item.startsAt) <= now.getTime() && Date.parse(item.endsAt) > now.getTime(); }
function periodKey(item, now) { return item.period === "month" ? item.id : dateVN(now); }
export function listPlans() { return PLANS; }
export function getSubscription(userId, now = new Date()) {
  const data = read(), record = data.subscriptions[userId] || { main: null, addons: [] };
  const main = active(record.main, now) ? record.main : null;
  const addons = record.addons.filter(a => active(a, now));
  return { main, addons, usage: data.usage[userId] || {} };
}
export function assignPlan({ userId, planId, months = 1, actorId, now = new Date() }) {
  const plan = planById(planId);
  if (!plan) throw new Error("INVALID_PLAN");
  if (!plan.addon && (!Number.isInteger(months) || months < 1 || months > 24)) throw new Error("INVALID_DURATION");
  const data = read();
  const record = data.subscriptions[userId] || { main: null, addons: [] };
  const item = { id: crypto.randomUUID(), planId, period: plan.period, startsAt: now.toISOString(), endsAt: (plan.addon ? endOfVietnamDay(now) : monthAfter(now, months)).toISOString() };
  if (plan.addon) record.addons.push(item);
  else { record.main = item; data.usage[userId] = {}; }
  data.subscriptions[userId] = record;
  data.logs.push({ id: crypto.randomUUID(), actorId, userId, action: "assign", planId, at: now.toISOString() });
  write(data);
  return item;
}
export function revokePlan({ userId, actorId, now = new Date() }) {
  const data = read();
  data.subscriptions[userId] = { main: null, addons: [] };
  data.logs.push({ id: crypto.randomUUID(), actorId, userId, action: "revoke", at: now.toISOString() });
  write(data);
}
export function getUsageStatus(userId, feature, now = new Date()) {
  const sub = getSubscription(userId, now);
  const mainPlan = sub.main && planById(sub.main.planId);
  const addons = sub.addons.map(item => ({ item, plan: planById(item.planId) }));
  const key = mainPlan ? periodKey(sub.main, now) : dateVN(now);
  const used = sub.usage[feature]?.[key] || 0;
  const extra = addons.filter(a => a.plan).reduce((sum, a) => sum + a.plan.limit, 0);
  const limit = mainPlan?.limit === null && mainPlan ? null : (mainPlan?.limit || 0) + extra;
  return { feature, planId: mainPlan?.id || null, used, limit, remaining: limit === null ? null : Math.max(0, limit - used), allowed: limit === null || used < limit };
}
// Call only after a successful feature operation. A single Node.js process serializes these sync updates.
export function consumeUsage(userId, feature, requestId, now = new Date()) {
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(feature)) throw new Error("INVALID_FEATURE");
  if (!requestId || String(requestId).length > 128) throw new Error("INVALID_REQUEST_ID");
  const status = getUsageStatus(userId, feature, now);
  const data = read();
  const key = status.planId && planById(status.planId).period === "month" ? data.subscriptions[userId].main.id : dateVN(now);
  const entries = data.usage[userId] ||= {};
  const seen = entries._requests ||= {};
  const dedupe = feature + ":" + key + ":" + requestId;
  if (seen[dedupe]) return { ...status, duplicate: true };
  if (!status.allowed) return { ...status, consumed: false };
  const counts = entries[feature] ||= {};
  counts[key] = (counts[key] || 0) + 1;
  seen[dedupe] = now.toISOString();
  write(data);
  return { ...getUsageStatus(userId, feature, now), consumed: true };
}
export function getAuditLogs() { return read().logs.slice(-200).reverse(); }
