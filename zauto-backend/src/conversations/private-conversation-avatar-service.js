import { ThreadType } from "zca-js";
import { getUserAvatars } from "../users/user-avatar-service.js";
import { getUserConversationList, syncConversationGroups } from "./conversation-store.js";

// Repair older private indexes that stored the last sender's avatar.
// Always resolve by the peer/thread ID, independently of message direction.
export async function refreshPrivateConversationAvatars(
  userId,
  { getAvatars = getUserAvatars } = {},
) {
  const peers = getUserConversationList(userId)
    .filter(item => item.type === "user")
    .map(item => String(item.groupId).trim())
    .filter(Boolean);
  if (peers.length === 0) return getUserConversationList(userId);

  try {
    const avatars = await getAvatars(userId, peers);
    const current = new Map(getUserConversationList(userId)
      .map(item => [String(item.groupId), item]));
    const updates = peers.flatMap(groupId => {
      const avatar = avatars?.[groupId]?.toString().trim();
      return avatar && avatar !== current.get(groupId)?.avatar
        ? [{ groupId, type: "user", avatar }]
        : [];
    });
    if (updates.length > 0) syncConversationGroups(userId, updates);
  } catch (error) {
    // Profile lookup must not prevent the user from opening Messages.
    console.warn("[PRIVATE AVATAR] REFRESH ERROR:", userId, error?.message ?? error);
  }
  return getUserConversationList(userId);
}

export async function getConversationEventAvatars(
  userId,
  message,
  { getAvatars = getUserAvatars } = {},
) {
  const senderId = String(message?.data?.uidFrom ?? "").trim();
  const peerId = message?.type === ThreadType.User
    ? String(message?.threadId ?? "").trim()
    : "";
  const ids = [...new Set([senderId, peerId].filter(Boolean))];
  if (ids.length === 0) return { senderAvatar: null, peerAvatar: null };
  const avatars = await getAvatars(userId, ids);
  return {
    senderAvatar: avatars?.[senderId] ?? null,
    peerAvatar: peerId ? avatars?.[peerId] ?? null : null,
  };
}
