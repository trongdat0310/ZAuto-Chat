// User group metadata changes slowly; chat messages arrive via a separate listener.
// Cache ONLY group metadata. Always overlay the current per-user notification settings.
export const USER_GROUP_CACHE_TTL_MS = 5 * 60 * 1000;

export function createUserGroupDirectory({
  connect, readSettings, now = () => Date.now(),
  ttlMs = USER_GROUP_CACHE_TTL_MS, logger = console,
} = {}) {
  if (typeof connect !== "function" || typeof readSettings !== "function" ||
      typeof now !== "function" || !Number.isFinite(ttlMs) || ttlMs < 0) {
    throw new Error("INVALID_GROUP_DIRECTORY_CONFIG");
  }

  const snapshots = new Map();
  const pending = new Map();

  function overlaySettings(groups, userId) {
    const settings = readSettings(userId) || {};
    // Do not let callers mutate cached metadata or cache enabled flags.
    return groups.map(group => ({
      ...group,
      enabled: settings[group.groupId]?.enabled === true,
    }));
  }

  async function getUserGroups(userId, { forceRefresh = false } = {}) {
    const key = String(userId);
    const api = await connect(key);
    const existing = snapshots.get(key);
    const active = pending.get(key);

    // Coalesce concurrent requests for the same active Zalo connection.
    // An explicit refresh in flight also takes precedence over an older cache.
    if (active?.api === api) {
      const groups = await active.promise;
      return overlaySettings(groups, key);
    }

    const time = now();
    if (!forceRefresh && existing?.api === api &&
        time >= existing.fetchedAt && time - existing.fetchedAt < ttlMs) {
      return overlaySettings(existing.groups, key);
    }

    const refresh = (async () => {
      logger.log?.("[USER GROUPS] Loading:", key);
      const response = await api.getAllGroups();
      const ids = Object.keys(response?.gridVerMap ?? {});
      const info = ids.length ? await api.getGroupInfo(ids) : null;
      const groups = ids.map(groupId => {
        const entry = info?.gridInfoMap?.[groupId];
        return {
          groupId: String(groupId),
          name: entry?.name ?? "Unknown Group",
          avatar: entry?.avatar ?? entry?.avt ?? entry?.fullAvt ?? null,
          totalMember: entry?.totalMember ?? 0,
        };
      });
      groups.sort((a, b) => a.name.localeCompare(b.name, "vi"));
      logger.log?.("[USER GROUPS] " + key + ": " + groups.length + " group(s)");
      return groups;
    })();

    pending.set(key, { api, promise: refresh });
    try {
      const groups = await refresh;
      // A reconnect may have superseded this request. Never let an older
      // Zalo connection overwrite a snapshot from a newer connection.
      if (pending.get(key)?.promise === refresh) {
        snapshots.set(key, {
          api, groups, fetchedAt: now(),
          names: new Map(groups.map(group => [group.groupId, group.name])),
        });
      }
      return overlaySettings(groups, key);
    } finally {
      if (pending.get(key)?.promise === refresh) pending.delete(key);
    }
  }

  function getUserGroupName(userId, groupId) {
    return snapshots.get(String(userId))?.names.get(String(groupId)) ??
      "Unknown Group";
  }

  function clearUserGroupCache(userId) {
    const key = String(userId);
    snapshots.delete(key);
    pending.delete(key);
  }

  return { getUserGroups, getUserGroupName, clearUserGroupCache };
}
