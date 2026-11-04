// Per-process protection for authentication endpoints. No trust in X-Forwarded-For.
// For multiple backend replicas, replace with a shared atomic store (Redis).
import { createHash } from "node:crypto";

export function createAuthRateLimiter({ windowMs = 15 * 60_000, max = 10, now = Date.now } = {}) {
  const attempts = new Map();
  return function authRateLimiter(req, res, next) {
    const current = now();
    if (attempts.size > 10000) {
      for (const [key, item] of attempts) {
        if (item.expiresAt <= current) attempts.delete(key);
      }
      if (attempts.size > 10000) {
        return res.status(503).json({ success: false, error: "May chu dang ban. Vui long thu lai sau." });
      }
    }
    const remote = String(req.socket?.remoteAddress || req.ip || "unknown");
    const identity = String(req.body?.phone ?? req.body?.email ?? "")
      .trim().toLowerCase().slice(0, 254);
    const digest = createHash("sha256").update(remote + "\0" + identity).digest("hex");
    const key = req.path + ":" + digest;
    let item = attempts.get(key);
    if (!item || item.expiresAt <= current) {
      item = { count: 0, expiresAt: current + windowMs };
      attempts.set(key, item);
    }
    item.count++;
    if (item.count > max) {
      res.setHeader("Retry-After", String(Math.max(1, Math.ceil((item.expiresAt - current) / 1000))));
      return res.status(429).json({ success: false, error: "Qua nhieu yeu cau. Vui long thu lai sau." });
    }
    return next();
  };
}
