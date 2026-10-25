import { acceptTargetKey, runMeteredAcceptance } from "../subscriptions/acceptance-runner.js";
import { subscriptionError } from "../subscriptions/subscription-service.js";

const identifier = value => typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);

// Dependencies are injected so validation, payload and metering can be tested without Zalo.
export function createChatAcceptService({ findMessage, getGroups, connect, groupType, store }) {
  return async function acceptChatMessage(userId, input) {
    const { groupId, msgId = null, cliMsgId = null, replyText = "Nh\u1eadn" } = input || {};
    if (!identifier(groupId) || (!msgId && !cliMsgId) ||
        (msgId !== null && !identifier(msgId)) || (cliMsgId !== null && !identifier(cliMsgId))) {
      throw subscriptionError("INVALID_ACCEPT_TARGET", "Tin nhan nhan cuoc khong hop le.");
    }
    if (typeof replyText !== "string" || !replyText.trim() || replyText.trim().length > 1000) {
      throw subscriptionError("INVALID_ACCEPT_REPLY", "Noi dung nhan cuoc phai co tu 1 den 1000 ky tu.");
    }
    const target = findMessage(userId, groupId, { msgId, cliMsgId });
    if (!target || String(target.groupId) !== groupId ||
        (msgId && String(target.msgId) !== msgId) || (cliMsgId && String(target.cliMsgId) !== cliMsgId)) {
      throw subscriptionError("REPLY_TARGET_NOT_FOUND", "Khong tim thay tin nhan trong tai khoan nay.", 404);
    }
    if (target.status !== "normal" || target.isSelf || typeof target.rawData?.content !== "string") {
      throw subscriptionError("ACCEPT_TARGET_UNAVAILABLE", "Chi nhan tu tin van ban cua nguoi khac con hieu luc.", 409);
    }
    // zca-js requires the original message.data as "quote" for a real
    // Zalo reply. Mentioning the sender alone does not reply to the message.
    const quote = target.rawData;
    if (quote.msgId == null && quote.cliMsgId == null) {
      throw subscriptionError("REPLY_TARGET_UNAVAILABLE", "Tin nhan goc thieu Zalo message ID.", 409);
    }
    const senderId = String(target.uidFrom ?? target.rawData.uidFrom ?? "");
    if (!/^\d+$/.test(senderId)) throw subscriptionError("INVALID_ACCEPT_SENDER", "Tin nhan thieu nguoi gui hop le.");
    const groups = await getGroups(userId);
    const group = groups.find(group => String(group.groupId) === groupId);
    if (!group) {
      throw subscriptionError("GROUP_NOT_FOUND", "Nhom khong thuoc tai khoan Zalo nay.", 404);
    }
    const senderName = String(target.senderName || target.rawData.dName || "ng\u01b0\u1eddi g\u1eedi")
      .replace(/[\r\n\t]/g, " ").trim().slice(0, 100);
    const mention = `@${senderName}`;
    const text = `${mention} ${replyText.trim()}`;
    const key = acceptTargetKey(groupId, target.msgId, target.cliMsgId);
    return runMeteredAcceptance({ userId, feature: "chat_accept", targetKey: key, store,
      context: { groupId, groupName: group.name || group.groupName || "Nh\u00f3m Zalo",
        sourceMsgId: target.msgId, sourceCliMsgId: target.cliMsgId,
        sourceContent: target.rawData.content, sourceTimestamp: target.rawData.ts ?? target.timestamp,
        senderId, senderName, acceptanceSource: "chat_accept", replyText: replyText.trim() },
      perform: async markSending => {
        const api = await connect(userId);
        markSending();
        const sent = await api.sendMessage({ msg: text, quote,
          mentions: [{ pos: 0, uid: senderId, len: mention.length }] }, groupId, groupType);
        if (sent?.message?.msgId == null && sent?.msgId == null) throw new Error("Zalo did not confirm a message ID");
        return { groupId, sourceMsgId: target.msgId, sourceCliMsgId: target.cliMsgId,
          replyText: replyText.trim(), text, mentionedUserId: senderId,
          replyZaloMessageId: sent?.message?.msgId ?? sent?.msgId ?? null,
          replyZaloCliMessageId: sent?.message?.cliMsgId ?? sent?.cliMsgId ?? null,
          acceptedAt: new Date().toISOString() };
      },
    });
  };
}
