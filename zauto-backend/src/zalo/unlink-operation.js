// Per-account coordinator for the explicit "Unlink Zalo" action.
// Transport failure / listener disconnect never invokes this cleanup.
export function createZaloUnlinkOperation({
  cancelQrLogin, stopWorker, cancelMetadata, flushMessages,
  purgeFiles, clearCaches, markUnlinked, notify,
} = {}) {
  for (const [name, callback] of Object.entries({
    cancelQrLogin, stopWorker, cancelMetadata, flushMessages,
    purgeFiles, clearCaches, markUnlinked, notify,
  })) {
    if (typeof callback !== "function") {
      throw new Error("INVALID_UNLINK_OPERATION_" + name);
    }
  }

  const pending = new Map();

  async function unlink(userId) {
    const key = String(userId);
    if (pending.has(key)) return pending.get(key);

    const action = (async () => {
      // The QR job and realtime worker must stop before removing files.
      cancelQrLogin(key);
      await stopWorker(key);
      cancelMetadata(key);
      // Trip messages are write-behind; wait for any pending write so a
      // stale async flush cannot recreate messages.json after deletion.
      await flushMessages(key);

      const cleanup = purgeFiles(key);
      clearCaches(key);
      const user = markUnlinked(key);
      if (!user) throw new Error("USER_NOT_FOUND");

      // UI synchronization is best effort; unlink already committed.
      try {
        notify(key);
      } catch {
        // A disconnected device can reload its profile after reconnect.
      }

      return { user, cleanup };
    })();

    pending.set(key, action);
    try {
      return await action;
    } finally {
      if (pending.get(key) === action) pending.delete(key);
    }
  }

  return { unlink };
}
