import { acceptTargetKey } from "./acceptance-runner.js";

const aliases = row => {
  const group = row.sourceThreadId ?? row.groupId;
  if (!group) return [];
  return [["msg", row.sourceMsgId ?? row.zaloMessageId], ["cli", row.sourceCliMsgId ?? row.clientMessageId]]
    .filter(([, id]) => id != null && String(id) !== "")
    .map(([type, id]) => JSON.stringify([String(group), type, String(id)]));
};

// Ledger success is authoritative. Merge it with the bounded trip cache so a
// process/disk failure after Zalo confirmed cannot hide the accepted trip.
export function mergeAcceptedHistory(messages, operations, limit = 500) {
  const byAlias = new Map(), result = new Map();
  for (const message of messages) {
    for (const alias of aliases(message)) byAlias.set(alias, message);
    if (message.status === "accepted") result.set(message.id, { ...message });
  }
  for (const operation of operations) {
    if (operation.status !== "succeeded") continue;
    const data = { ...operation.context, ...operation.result };
    if (!data.groupId || (!data.sourceMsgId && !data.sourceCliMsgId)) continue;
    const matches = aliases(data).map(key => byAlias.get(key)).filter(Boolean);
    const existing = matches[0];
    for (const match of matches) result.delete(match.id);
    const id = existing?.id || `accepted-${operation.targetKey}`;
    const row = { ...existing, id, groupId: data.groupId, sourceThreadId: data.groupId,
      groupName: data.groupName || existing?.groupName || "Nh\u00f3m Zalo",
      sourceMsgId: data.sourceMsgId ?? existing?.sourceMsgId ?? null,
      sourceCliMsgId: data.sourceCliMsgId ?? existing?.sourceCliMsgId ?? null,
      content: data.sourceContent ?? existing?.content ?? "Cu\u1ed1c \u0111\u00e3 nh\u1eadn",
      senderId: data.senderId ?? existing?.senderId ?? null,
      senderName: data.senderName ?? existing?.senderName ?? null,
      status: "accepted", acceptanceSource: operation.feature,
      acceptedAt: data.acceptedAt || operation.updatedAt || operation.createdAt,
      receivedAt: existing?.receivedAt || operation.createdAt,
      replyText: data.replyText ?? existing?.replyText,
      replyZaloMessageId: data.replyZaloMessageId ?? existing?.replyZaloMessageId ?? null,
      replyZaloCliMessageId: data.replyZaloCliMessageId ?? existing?.replyZaloCliMessageId ?? null };
    result.set(id, row);
    for (const alias of aliases(row)) byAlias.set(alias, row);
  }
  return [...result.values()].sort((a, b) => String(b.acceptedAt || "").localeCompare(String(a.acceptedAt || "")))
    .slice(0, Math.max(1, Math.min(limit, 500)));
}

export function createAcceptanceProjection({ saveMessage, updateMessage, broadcast }) {
  return function project(userId, data) {
    if (!data.groupId || (!data.sourceMsgId && !data.sourceCliMsgId)) return null;
    const { message } = saveMessage(userId, {
      groupId: data.groupId, groupName: data.groupName,
      senderId: data.senderId, senderName: data.senderName,
      zaloMessageId: data.sourceMsgId, clientMessageId: data.sourceCliMsgId,
      sourceThreadId: data.groupId, sourceMsgId: data.sourceMsgId, sourceCliMsgId: data.sourceCliMsgId,
      sourceTimestamp: data.sourceTimestamp, content: data.sourceContent,
    });
    const updated = updateMessage(userId, message.id, { status: "accepted",
      acceptedAt: data.acceptedAt, acceptanceSource: data.acceptanceSource || "chat_accept",
      replyText: data.replyText, replyZaloMessageId: data.replyZaloMessageId ?? null,
      replyZaloCliMessageId: data.replyZaloCliMessageId ?? null });
    if (!updated) throw new Error("Accepted trip projection could not be saved");
    // A socket error does not undo an external send or spend a second credit.
    try { broadcast(userId, "trip_accepted", { messageId: updated.id, message: updated,
      source: updated.acceptanceSource, targetKey: acceptTargetKey(data.groupId, data.sourceMsgId, data.sourceCliMsgId) }); }
    catch { /* GET history repairs the UI after reconnect. */ }
    return updated;
  };
}
