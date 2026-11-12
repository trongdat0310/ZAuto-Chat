import { cancelZaloLink } from "./link-manager.js";
import { stopUserWorker } from "../workers/user-worker-manager.js";
import { cancelUserGroupMetadata, clearUserGroupCache } from "./user-groups.js";
import { clearUserGroupSettingsCache } from "./user-group-settings.js";
import { flushUserMessages, clearUserMessageCache } from "../messages/user-message-store.js";
import { clearUserMessageDedupeCache } from "../messages/user-message-dedupe.js";
import { clearUserMessageSettingsCache } from "../settings/user-message-settings-store.js";
import { clearUserAvatarCache } from "../users/user-avatar-service.js";
import { invalidateUserFilterCache } from "../filters/user-filter-store.js";
import { invalidateUserFilterRuntime } from "../filters/user-filter-runtime.js";
import { clearUserConversationSendCache } from "../conversations/conversation-send-idempotency.js";
import { updateUser } from "../users/user-store.js";
import { broadcastUserEvent } from "../realtime/ws-server.js";
import { purgeUserZaloFiles } from "./user-zalo-data-cleanup.js";
import { createZaloUnlinkOperation } from "./unlink-operation.js";

function clearZaloCaches(userId) {
  clearUserGroupCache(userId);
  clearUserGroupSettingsCache(userId);
  clearUserMessageCache(userId);
  clearUserMessageDedupeCache(userId);
  clearUserMessageSettingsCache(userId);
  clearUserAvatarCache(userId);
  invalidateUserFilterCache(userId);
  invalidateUserFilterRuntime(userId);
  clearUserConversationSendCache(userId);
}

const operation = createZaloUnlinkOperation({
  cancelQrLogin: cancelZaloLink,
  stopWorker: stopUserWorker,
  cancelMetadata: cancelUserGroupMetadata,
  flushMessages: flushUserMessages,
  purgeFiles: purgeUserZaloFiles,
  clearCaches: clearZaloCaches,
  markUnlinked: userId => updateUser(userId, {
    zaloLinked: false,
    zaloUserId: null,
    // Past accepted-trip details remain only in the accounting ledger.
    // The app must not display their Zalo content after a new account links.
    zaloDataClearedAt: new Date().toISOString(),
  }),
  notify: userId => broadcastUserEvent(userId, "zalo_unlinked", {
    cleared: true,
  }),
});

export const unlinkUserZalo = userId => operation.unlink(userId);
