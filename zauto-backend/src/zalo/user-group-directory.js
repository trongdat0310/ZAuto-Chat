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
          totalMember: Number.isFinite(Number(item.totalMember))
            ? Number(item.totalMember) : 0,
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
    const name = fromEvent || existing?.name || displayName(id);
    if (existing && (!fromEvent || existing.name === fromEvent)) return existing;

    // Only the authenticated listener may call this. Every user has
    // a separate persisted conversation index and enabled settings.
    const group = {
      groupId: id,
      name,
      type: 'group',
      ...(existing?.avatar ? { avatar: existing.avatar } : {}),
    };
    persistGroups(String(userId), [group]);
    const record = {
      groupId: id, name,
      avatar: existing?.avatar ?? null,
      totalMember: existing?.totalMember ?? 0,
    };
    known.set(id, record);
    logger.log?.('[USER GROUPS] Discovered from message:', String(userId), id);
    return record;
  }

  function clearUserGroupCache(userId) {
    snapshots.delete(String(userId));
  }

  return { getUserGroups, getUserGroupName, discoverUserGroup, clearUserGroupCache };
}
