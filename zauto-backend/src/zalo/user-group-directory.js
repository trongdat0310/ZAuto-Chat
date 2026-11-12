// Group metadata is discovered from authenticated Zalo message events.
// Never request the full Zalo group directory; keep old local conversations.
function safeId(input) {
  const id = String(input ?? '').trim();
  if (!id || id.length > 128 || /[\x00-\x1f\x7f]/.test(id)) return '';
  return id;
}

function displayName(id) {
  return `Nhóm ${id}`;
}

function safeAvatar(value) {
  if (typeof value !== 'string') return '';
  const url = value.trim();
  if (url.startsWith('//')) return `https:${url}`;
  return /^https?:\/\//i.test(url) ? url : '';
}

function eventGroupAvatar(event) {
  const data = event?.data ?? {};
  const choices = [
    event?.group?.fullAvt, event?.group?.avt,
    event?.groupAvatar, event?.groupFullAvt,
    data?.group?.fullAvt, data?.group?.avt,
    data?.groupAvatar, data?.groupFullAvt,
  ];
  for (const value of choices) {
    const avatar = safeAvatar(value);
    if (avatar) return avatar;
  }
  return '';
}

function isGroupConversation(item) {
  if (!item || typeof item !== 'object') return false;
  const type = String(item.type ?? 'group').toLowerCase();
  return !['user', 'private', 'dm', 'personal'].includes(type);
}

function eventGroupName(event) {
  // data.dName and senderName are the SENDER name, not the group name.
  const data = event?.data ?? {};
  const choices = [
    event?.groupName, event?.threadName,
    data?.groupName, data?.threadName,
    data?.group?.name, data?.thread?.name,
  ];
  for (const value of choices) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim().slice(0, 180);
    }
  }
  return '';
}

export function createUserGroupDirectory({
  readConversations,
  persistGroups,
  readSettings,
  logger = console,
} = {}) {
  if (typeof readConversations !== 'function' ||
      typeof persistGroups !== 'function' ||
      typeof readSettings !== 'function') {
    throw new Error('INVALID_GROUP_DIRECTORY_CONFIG');
  }
  const snapshots = new Map();

  function listStored(userId) {
    const items = readConversations(String(userId));
    return (Array.isArray(items) ? items : [])
      .filter(isGroupConversation)
      .map(item => {
        const groupId = safeId(item.groupId ?? item.threadId);
        if (!groupId) return null;
        return {
          groupId,
          name: typeof item.name === 'string' && item.name.trim()
            ? item.name.trim() : displayName(groupId),
          avatar: item.avatar ?? null,
          totalMember: item.totalMember != null &&
            Number.isInteger(Number(item.totalMember)) &&
            Number(item.totalMember) >= 0
              ? Number(item.totalMember) : null,
        };
      })
      .filter(Boolean);
  }

  function hydrate(userId) {
    const key = String(userId);
    if (!snapshots.has(key)) {
      snapshots.set(key, new Map(listStored(key).map(item => [item.groupId, item])));
    }
    return snapshots.get(key);
  }

  async function getUserGroups(userId, _options = {}) {
    const key = String(userId);
    const settings = readSettings(key) || {};
    // Read the persisted index on request; no Zalo group API is called.
    const groups = listStored(key);
    const known = hydrate(key);
    for (const group of groups) known.set(group.groupId, group);
    return groups.map(group => ({
      ...group,
      enabled: settings[group.groupId]?.enabled === true,
    })).sort((a, b) => a.name.localeCompare(b.name, 'vi'));
  }

  function getUserGroupName(userId, groupId) {
    const id = safeId(groupId);
    if (!id) return 'Nhóm không xác định';
    return hydrate(String(userId)).get(id)?.name ?? displayName(id);
  }

  function discoverUserGroup(userId, event) {
    const id = safeId(event?.threadId);
    if (!id) return null;
    const known = hydrate(String(userId));
    const existing = known.get(id);
    const fromEvent = eventGroupName(event);
    const fromAvatar = eventGroupAvatar(event);
    const name = fromEvent || existing?.name || displayName(id);
    const avatar = fromAvatar || existing?.avatar || null;
    if (existing && name === existing.name && avatar === existing.avatar) {
      return existing;
    }

    // Only the authenticated listener may call this. Every user has
    // a separate persisted conversation index and enabled settings.
    persistGroups(String(userId), [{
      groupId: id,
      name,
      type: 'group',
      ...(avatar ? { avatar } : {}),
    }]);
    const record = {
      groupId: id, name, avatar,
      totalMember: existing?.totalMember ?? null,
    };
    known.set(id, record);
    logger.log?.('[USER GROUPS] Discovered from message:', String(userId), id);
    return record;
  }

  function applyUserGroupMetadata(userId, groupId, info) {
    const id = safeId(groupId);
    if (!id || !info || typeof info !== 'object') return null;
    const known = hydrate(String(userId));
    const existing = known.get(id);
    // A profile lookup alone cannot add an undiscovered group.
    if (!existing) return null;

    const name = typeof info.name === 'string' && info.name.trim()
      ? info.name.trim().slice(0, 180) : existing.name;
    const avatar = safeAvatar(info.fullAvt) || safeAvatar(info.avt) ||
      safeAvatar(info.avatar) || existing.avatar;
    const totalMember = info.totalMember != null &&
      Number.isInteger(Number(info.totalMember)) &&
      Number(info.totalMember) >= 0
        ? Number(info.totalMember) : existing.totalMember;
    if (name === existing.name && avatar === existing.avatar &&
        totalMember === existing.totalMember) return null;

    persistGroups(String(userId), [{
      groupId: id, type: 'group', name,
      ...(avatar ? { avatar } : {}),
      ...(totalMember != null ? { totalMember } : {}),
    }]);
    const updated = { groupId: id, name, avatar: avatar ?? null,
      totalMember: totalMember ?? null };
    known.set(id, updated);
    return updated;
  }

  function clearUserGroupCache(userId) {
    snapshots.delete(String(userId));
  }

  return {
    getUserGroups, getUserGroupName, discoverUserGroup,
    applyUserGroupMetadata, clearUserGroupCache,
  };
}
