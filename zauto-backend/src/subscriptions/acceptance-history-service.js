import { getUserMessages, saveUserMessage, updateUserMessage } from "../messages/user-message-store.js";
import { broadcastUserEvent } from "../realtime/ws-server.js";
import { subscriptionService } from "./subscription-service.js";
import { createAcceptanceProjection, mergeAcceptedHistory } from "./acceptance-history.js";

export const projectAcceptedTrip = createAcceptanceProjection({
  saveMessage: saveUserMessage, updateMessage: updateUserMessage, broadcast: broadcastUserEvent,
});
export function getAcceptedTripHistory(userId) {
  return mergeAcceptedHistory(getUserMessages(userId, 500), subscriptionService.getAcceptedOperations(userId));
}
export function notifySubscriptionChanged(userId) {
  try { broadcastUserEvent(userId, "subscription_changed", {}); }
  catch { /* A failed websocket is not a failed database mutation. */ }
}
