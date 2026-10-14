import { ThreadType } from "zca-js";
import { connectUserZalo } from "../zalo/user-zalo-manager.js";
import { getUserMessageById, updateUserMessage } from "./user-message-store.js";
import { findUserConversationMessage } from "../conversations/conversation-store.js";
import { acceptTargetKey, runMeteredAcceptance } from "../subscriptions/acceptance-runner.js";
import { subscriptionError } from "../subscriptions/subscription-service.js";

const acceptInFlight = new Map();
const lockKey = (userId, messageId) => `${userId}:${messageId}`;

async function acceptInternal(userId, messageId, replyText) {
  const message = getUserMessageById(userId, messageId);
  if (!message) throw subscriptionError("MESSAGE_NOT_FOUND", "Khong tim thay cuoc.", 404);
  if (message.status === "accepted") return { alreadyAccepted: true, message };
  if (message.status === "ignored") throw subscriptionError("MESSAGE_ALREADY_IGNORED", "Cuoc nay da bi bo qua.", 409);
  const text = typeof replyText === "string" ? replyText.trim() : "";
  if (!text || text.length > 1000) throw subscriptionError("INVALID_ACCEPT_REPLY", "Noi dung nhan cuoc phai co tu 1 den 1000 ky tu.");
  const groupId = String(message.sourceThreadId ?? message.groupId ?? "");
  const msgId = message.sourceMsgId ?? message.zaloMessageId ?? null;
  const cliMsgId = message.sourceCliMsgId ?? message.clientMessageId ?? null;
  const source = (msgId || cliMsgId) ? findUserConversationMessage(userId, groupId, { msgId, cliMsgId }) : null;
  if (source && source.status !== "normal") throw subscriptionError("SOURCE_MESSAGE_UNAVAILABLE", "Tin nhan goc khong con kha dung.", 409);
  const raw = source?.rawData || message.sourceQuote;
  const quote = raw && (raw.msgId != null || raw.cliMsgId != null) ? {
    content: raw.content, msgType: raw.msgType, propertyExt: raw.propertyExt,
    uidFrom: raw.uidFrom, msgId: raw.msgId, cliMsgId: raw.cliMsgId, ts: raw.ts, ttl: raw.ttl ?? 0,
  } : null;
  if (!quote && (msgId || cliMsgId)) throw subscriptionError("SOURCE_MESSAGE_UNAVAILABLE", "Tin nhan goc chua san sang de tra loi.", 409);
  const targetKey = acceptTargetKey(groupId, source?.msgId ?? quote?.msgId ?? msgId,
    source?.cliMsgId ?? quote?.cliMsgId ?? cliMsgId ?? `trip-${messageId}`);
  const result = await runMeteredAcceptance({ userId, feature: "trip_screen_accept", targetKey,
    perform: async markSending => {
      const api = await connectUserZalo(userId);
      markSending();
      const sent = await api.sendMessage(quote ? { msg: text, quote } : text, groupId, ThreadType.Group);
      if (sent?.message?.msgId == null && sent?.msgId == null) throw new Error("Zalo did not confirm a message ID");
      return { groupId, replyText: text, sourceMsgId: msgId, sourceCliMsgId: cliMsgId,
        replyZaloMessageId: sent?.message?.msgId ?? sent?.msgId ?? null,
        replyZaloCliMessageId: sent?.message?.cliMsgId ?? sent?.cliMsgId ?? null,
        acceptedAt: new Date().toISOString() };
    },
  });
  // Persist the external success in the quota ledger BEFORE updating the trip store.
  // A retry repairs this local update without sending or charging again.
  const updated = updateUserMessage(userId, messageId, {
    status: "accepted", replyText: result.replyText ?? text,
    replyZaloMessageId: result.replyZaloMessageId != null ? String(result.replyZaloMessageId) : null,
    replyZaloCliMessageId: result.replyZaloCliMessageId != null ? String(result.replyZaloCliMessageId) : null,
    acceptedAt: result.acceptedAt,
  });
  if (!updated) throw subscriptionError("MESSAGE_NOT_FOUND", "Khong cap nhat duoc cuoc da nhan.", 404);
  return { alreadyAccepted: result.alreadyAccepted, message: updated };
}
export async function acceptUserMessage(userId, messageId, replyText = "Nhận") {
  const key = lockKey(userId, messageId);
  if (acceptInFlight.has(key)) return acceptInFlight.get(key);
  const promise = acceptInternal(userId, messageId, replyText);
  acceptInFlight.set(key, promise);
  try { return await promise; }
  finally { if (acceptInFlight.get(key) === promise) acceptInFlight.delete(key); }
}
export async function ignoreUserMessage(userId, messageId) {
  if (acceptInFlight.has(lockKey(userId, messageId))) throw subscriptionError("MESSAGE_ACCEPT_IN_PROGRESS", "Cuoc dang duoc nhan.", 409);
  const message = getUserMessageById(userId, messageId);
  if (!message) throw subscriptionError("MESSAGE_NOT_FOUND", "Khong tim thay cuoc.", 404);
  if (message.status === "accepted") throw subscriptionError("MESSAGE_ALREADY_ACCEPTED", "Cuoc nay da duoc nhan.", 409);
  if (message.status === "ignored") return { alreadyIgnored: true, message };
  return { alreadyIgnored: false, message: updateUserMessage(userId, messageId, {
    status: "ignored", ignoredAt: new Date().toISOString(),
  }) };
}
