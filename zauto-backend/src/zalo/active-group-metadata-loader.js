// Resolve metadata only for group IDs observed in authenticated Zalo events.
// No getAllGroups call and no batch getGroupInfo request.
export function createActiveGroupMetadataLoader({
  applyMetadata,
  logger = console,
  now = () => Date.now(),
  successTtlMs = 60 * 60 * 1000,
  failureBackoffMs = 5 * 60 * 1000,
  concurrency = 2,
  maxQueue = 100,
} = {}) {
  if (typeof applyMetadata !== "function") {
    throw new Error("GROUP_METADATA_CALLBACK_REQUIRED");
  }

  const retryAfter = new Map();
  const inFlight = new Map();
  const queue = [];
  const generations = new Map();

  function isCurrent(job) {
    return job.generation === (generations.get(job.userId) ?? 0);
  }

  let active = 0;

  function pump() {
    while (active < concurrency && queue.length > 0) {
      const job = queue.shift();
      active += 1;

      void (async () => {
        try {
          if (!isCurrent(job)) {
            job.resolve(null);
            return;
          }
          // string = exactly one group, never a bulk request.
          const response = await job.api.getGroupInfo(job.groupId);
          const info = response?.gridInfoMap?.[job.groupId];
          if (!info || (info.groupId != null &&
              String(info.groupId) !== job.groupId)) {
            throw new Error("GROUP_INFO_NOT_AVAILABLE");
          }

          if (!isCurrent(job)) {
            job.resolve(null);
            return;
          }
          const changed = applyMetadata(job.userId, job.groupId, info);
          retryAfter.set(job.key, now() + successTtlMs);
          job.resolve(changed ?? null);
        } catch (error) {
          if (!isCurrent(job)) {
            job.resolve(null);
            return;
          }
          retryAfter.set(job.key, now() + failureBackoffMs);
          logger.warn?.(
            "[USER GROUPS] Single-group metadata lookup failed:",
            job.userId, job.groupId, error?.message ?? error
          );
          // Metadata failure must never block receiving or saving messages.
          job.resolve(null);
        } finally {
          if (inFlight.get(job.key) === job.promise) {
            inFlight.delete(job.key);
          }
          active -= 1;
          pump();
        }
      })();
    }
  }

  function load(userId, groupId, api) {
    const account = String(userId ?? "").trim();
    const id = String(groupId ?? "").trim();
    if (!account || !id || !api || typeof api.getGroupInfo !== "function") {
      return Promise.resolve(null);
    }
    const key = JSON.stringify([account, id]);
    if (inFlight.has(key)) return inFlight.get(key);
    if (now() < (retryAfter.get(key) ?? 0)) return Promise.resolve(null);
    if (queue.length >= maxQueue) return Promise.resolve(null);

    let resolve;
    const promise = new Promise(done => { resolve = done; });
    inFlight.set(key, promise);
    queue.push({ key, userId: account, groupId: id, api, resolve,
      promise, generation: generations.get(account) ?? 0 });
    pump();
    return promise;
  }

  function cancelUser(userId) {
    const account = String(userId);
    generations.set(account, (generations.get(account) ?? 0) + 1);
    // Pending requests may still return from Zalo, but their results are ignored.
    for (let i = queue.length - 1; i >= 0; i--) {
      if (queue[i].userId !== account) continue;
      const [job] = queue.splice(i, 1);
      job.resolve(null);
    }
    for (const key of [...retryAfter.keys()]) {
      if (JSON.parse(key)[0] === account) retryAfter.delete(key);
    }
    for (const [key, value] of inFlight) {
      if (JSON.parse(key)[0] === account) inFlight.delete(key);
    }
  }

  return { load, cancelUser };
}
