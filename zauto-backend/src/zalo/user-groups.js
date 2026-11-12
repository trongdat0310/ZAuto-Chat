import { readUserGroupSettings } from "./user-group-settings.js";
import { getUserConversationList, syncConversationGroups } from "../conversations/conversation-store.js";
import { createUserGroupDirectory } from "./user-group-directory.js";
import { createActiveGroupMetadataLoader } from "./active-group-metadata-loader.js";

// Only locally persisted conversations are enumerated. Message listener
// discovers groups as they become active; no bulk Zalo group lookup occurs.
const directory = createUserGroupDirectory({
  readConversations: getUserConversationList,
  persistGroups: syncConversationGroups,
  readSettings: readUserGroupSettings,
});

// Requests are keyed by app account AND group ID and never enumerate all groups.
const groupMetadataLoader = createActiveGroupMetadataLoader({
  applyMetadata: (userId, groupId, info) =>
    directory.applyUserGroupMetadata(userId, groupId, info),
});

export const refreshActiveGroupMetadata = (userId, groupId, api) =>
  groupMetadataLoader.load(userId, groupId, api);

export const getUserGroups = (userId, options) =>
  directory.getUserGroups(userId, options);

export const getUserGroupName = (userId, groupId) =>
  directory.getUserGroupName(userId, groupId);

export const discoverUserGroup = (userId, message) =>
  directory.discoverUserGroup(userId, message);

export const clearUserGroupCache = userId =>
  directory.clearUserGroupCache(userId);
