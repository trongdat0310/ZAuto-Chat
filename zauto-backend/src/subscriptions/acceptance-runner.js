import crypto from "node:crypto";
import { subscriptionService, subscriptionError } from "./subscription-service.js";

// Keys come from the original stored Zalo target, never from a client request ID.
// Both manual accept flows use this same key; changing feature/day/plan cannot resend it.
export function acceptTargetKey(groupId, msgId, cliMsgId) {
  const id = msgId ? `msg:${msgId}` : cliMsgId ? `cli:${cliMsgId}` : null;
  if (!groupId || !id) throw subscriptionError("SOURCE_MESSAGE_UNAVAILABLE", "Tin nhan goc thieu ID.", 409);
  return crypto.createHash("sha256").update(JSON.stringify([String(groupId), id])).digest("hex");
}
export async function runMeteredAcceptance({ userId, feature, targetKey, perform, store = subscriptionService }) {
  const reservation = store.reserveUsage(userId, feature, targetKey);
  if (reservation.duplicate) return { ...reservation.operation.result, alreadyAccepted: true };
  let sending = false;
  try {
    const result = await perform(() => {
      store.transition(userId, reservation.operation, "sending");
      sending = true;
    });
    store.transition(userId, reservation.operation, "succeeded", result);
    return { ...result, alreadyAccepted: false };
  } catch (error) {
    // A timeout is NOT evidence of non-delivery. Retain the reservation and refuse
    // another send until an administrator verifies the external outcome.
    try { store.transition(userId, reservation.operation, sending ? "uncertain" : "failed"); }
    catch { /* Persistent pending record still prevents duplicate delivery; fail closed. */ }
    if (sending) throw subscriptionError("ACCEPT_OUTCOME_UNKNOWN", "Chua xac dinh ket qua gui. Khong gui lai de tranh trung; lien he Admin kiem tra.", 409);
    throw error;
  }
}
