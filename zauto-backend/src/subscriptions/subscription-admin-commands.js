import crypto from "node:crypto";

const fail = (code, message = code, status = 400) => Object.assign(new Error(message), { code, status });
const digest = value => crypto.createHash("sha256").update(JSON.stringify(value)).digest("hex");
export const subscriptionRevision = record => digest(record || { main: null, addons: [] });

// Run INSIDE the store's exclusive transaction. A retry must return its original
// result before checking revision, even when the first response was lost.
export function adminCommand(data, { actorId, userId, requestId, expectedRevision }, payload, apply) {
  if (requestId !== undefined && (typeof requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(requestId))) {
    throw fail("INVALID_REQUEST_ID", "Ma yeu cau quan tri khong hop le.");
  }
  if (expectedRevision !== undefined && (typeof expectedRevision !== "string" || !/^[a-f0-9]{64}$/.test(expectedRevision))) {
    throw fail("INVALID_REVISION", "Phien ban goi khong hop le.");
  }
  if (typeof payload.note !== "string" || payload.note.length > 500) throw fail("INVALID_NOTE");
  const key = requestId ? digest([actorId, requestId]) : null;
  const fingerprint = digest([userId, expectedRevision ?? null, payload]);
  const previous = key && data.adminCommands?.[key];
  if (previous) {
    if (previous.fingerprint !== fingerprint) throw fail("REQUEST_ID_CONFLICT", "Ma yeu cau da duoc dung cho thao tac khac.", 409);
    return structuredClone(previous.result);
  }
  if (expectedRevision !== undefined && expectedRevision !== subscriptionRevision(data.subscriptions[userId])) {
    throw fail("SUBSCRIPTION_CHANGED", "Goi da thay doi. Hay tai lai truoc khi thao tac.", 409);
  }
  const result = apply();
  if (key) (data.adminCommands ||= {})[key] = { fingerprint, result: structuredClone(result), actorId, userId };
  return result;
}

export function renewMain(main, months, now, monthAfterVN, endOfDayVN) {
  if (!main) throw fail("PLAN_REQUIRED", "Tai khoan khong co goi de gia han.", 409);
  if (!Number.isInteger(months) || months < 1 || months > 24) throw fail("INVALID_DURATION");
  const start = new Date(main.startsAt), end = new Date(main.endsAt);
  if (!Number.isFinite(+now) || !Number.isFinite(+start) || !Number.isFinite(+end) || end <= start || start > now) {
    throw fail("SUBSCRIPTION_STORE_INVALID", "Thoi han goi khong hop le.", 503);
  }
  if (end <= now) {
    return { ...main, id: crypto.randomUUID(), startsAt: now.toISOString(), endsAt: endOfDayVN(monthAfterVN(now, months)).toISOString() };
  }
  // Extend by calendar months from the current expiry day in Vietnam.
  // The stored timestamp is the last millisecond of that local day.
  return { ...main, endsAt: endOfDayVN(monthAfterVN(end, months)).toISOString() };
}
