import { readUserGroupSettings } from "./user-group-settings.js";
import { getUserConversationList, syncConversationGroups } from "../conversations/conversation-store.js";
import { createUserGroupDirectory } from "./user-group-directory.js";

// Only locally persisted conversations are enumerated. Message listener
// discovers groups as they become active; no bulk Zalo group lookup occurs.
const directory = createUserGroupDirectory({
  readConversations: getUserConversationList,
  persistGroups: syncConversationGroups,
  readSettings: readUserGroupSettings,
});

export const getUserGroups = (userId, options) =>
  directory.getUserGroups(userId, options);

export const getUserGroupName = (userId, groupId) =>
  directory.getUserGroupName(userId, groupId);

export const discoverUserGroup = (userId, message) =>
  directory.discoverUserGroup(userId, message);

export const clearUserGroupCache = userId =>
  directory.clearUserGroupCache(userId);
