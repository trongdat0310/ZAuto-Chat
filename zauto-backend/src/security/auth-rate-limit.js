// Authentication throttling for a single Node.js process.
// Do not trust forwarded IP headers unless a trusted proxy is configured.
// Use a shared atomic store (e.g. Redis) before running multiple replicas.
import { createHash } from "node:crypto";

export function createAuthRateLimiter({
  windowMs = 15 * 60_000,
  max = 10,
  ipMax = 100,
  ipWindowMs = windowMs,
  failureOnly = false,
  now = Date.now,
  maxEntries = 50000,
} = {}) {
  const counters = new Map();
  const hash = value => createHash("sha256").update(value).digest("hex");
  function prune(current) {
    for (const [key, value] of counters) {
      if (value.expiresAt <= current) counters.delete(key);
    }
  }
  function get(key, current, duration) {
    let entry = counters.get(key);
    if (!entry || entry.expiresAt <= current) {
      entry = { count: 0, expiresAt: current + duration };
      counters.set(key, entry);
    }
    return entry;
  }
  function limited(entry, maximum, current) {
    return entry && entry.count >= maximum && entry.expiresAt > current;
  }
  function reject(res, entry, current) {
    res.setHeader("Retry-After", String(Math.max(1, Math.ceil((entry.expiresAt - current) / 1000))));
    return res.status(429).json({
      success: false,
      error: "Qua nhieu yeu cau. Vui long thu lai sau.",
    });
  }
  return function authRateLimiter(req, res, next) {
    const current = now();
    // Never allow an unbounded number of unique identities to exhaust memory.
    if (counters.size >= maxEntries) prune(current);
    if (counters.size >= maxEntries) {
      return res.status(503).json({ success: false, error: "May chu dang ban. Vui long thu lai sau." });
    }
    const ip = String(req.socket?.remoteAddress || req.ip || "unknown");
    const identity = String(req.body?.phone ?? req.body?.email ?? "")
      .trim().toLowerCase().slice(0, 254);
    const prefix = req.path + ":";
    const ipKey = prefix + "ip:" + hash(ip);
    const accountKey = prefix + "account:" + hash(identity || ip);
    const ipEntry = get(ipKey, current, ipWindowMs);
    const accountEntry = get(accountKey, current, windowMs);
    if (limited(ipEntry, ipMax, current)) return reject(res, ipEntry, current);
    if (limited(accountEntry, max, current)) return reject(res, accountEntry, current);

    // The IP ceiling always counts requests, preventing account rotation.
    ipEntry.count++;
    if (!failureOnly) accountEntry.count++;
    if (failureOnly) {
      // Failed authentication only; successful logins do not consume account allowance.
      // Capture response status on completion without changing the route handler.
      res.once("finish", () => {
        if (res.statusCode === 401) {
          const entry = get(accountKey, now(), windowMs);
          entry.count++;
        }
      });
    }
    return next();
  };
}
