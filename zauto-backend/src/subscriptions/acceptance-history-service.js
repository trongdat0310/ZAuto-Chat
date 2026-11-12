import { getUserMessages, saveUserMessage, updateUserMessage } from "../messages/user-message-store.js";
import { broadcastUserEvent } from "../realtime/ws-server.js";
import { subscriptionService } from "./subscription-service.js";
import { createAcceptanceProjection, mergeAcceptedHistory, visibleHistorySinceZaloReset } from "./acceptance-history.js";
import { findUserById } from "../users/user-store.js";

export const projectAcceptedTrip = createAcceptanceProjection({
  saveMessage: saveUserMessage, updateMessage: updateUserMessage, broadcast: broadcastUserEvent,
});
export function getAcceptedTripHistory(userId) {
  const user = findUserById(userId);
  // While unlinked, Zalo trips are no longer available in the app.
  if (user?.zaloDataClearedAt && user.zaloLinked !== true) return [];
  return visibleHistorySinceZaloReset(
    mergeAcceptedHistory(getUserMessages(userId, 500), subscriptionService.getAcceptedOperations(userId)),
    user?.zaloDataClearedAt
  );
}
export function notifySubscriptionChanged(userId) {
  try { broadcastUserEvent(userId, "subscription_changed", {}); }
  catch { /* A failed websocket is not a failed database mutation. */ }
}
