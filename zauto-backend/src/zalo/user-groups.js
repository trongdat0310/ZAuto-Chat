import { connectUserZalo } from "./user-zalo-manager.js";
import { readUserGroupSettings } from "./user-group-settings.js";
import { createUserGroupDirectory } from "./user-group-directory.js";

// One directory for each backend process; per-user entries are separated.
// Live Zalo listeners do not depend on this list being refreshed.
const directory = createUserGroupDirectory({
  connect: connectUserZalo,
  readSettings: readUserGroupSettings,
});

export const getUserGroups = (userId, options) =>
  directory.getUserGroups(userId, options);

export const getUserGroupName = (userId, groupId) =>
  directory.getUserGroupName(userId, groupId);

export const clearUserGroupCache = userId =>
  directory.clearUserGroupCache(userId);
