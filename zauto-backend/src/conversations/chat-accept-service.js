import { ThreadType } from "zca-js";
import { connectUserZalo } from "../zalo/user-zalo-manager.js";
import { getUserGroups } from "../zalo/user-groups.js";
import { findUserConversationMessage } from "./conversation-store.js";
import { createChatAcceptService } from "./chat-accept-core.js";
import { projectAcceptedTrip, notifySubscriptionChanged } from "../subscriptions/acceptance-history-service.js";

const accept = createChatAcceptService({
  findMessage: findUserConversationMessage, getGroups: getUserGroups,
  connect: connectUserZalo, groupType: ThreadType.Group,
});
export async function acceptUserChatMessage(userId, input) {
  const result = await accept(userId, input);
  let message = null, historySyncPending = false;
  try { message = projectAcceptedTrip(userId, result); }
  catch { historySyncPending = true; console.error("[CHAT ACCEPT] History projection pending", userId); }
  notifySubscriptionChanged(userId);
  // Ledger success must still be acknowledged if the secondary history store failed.
  return { ...result, messageId: message?.id ?? null, historySyncPending };
}
