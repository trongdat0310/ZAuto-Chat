import { isIP } from "node:net";

// Only enable when the origin is reachable exclusively through a trusted
// local Cloudflare Tunnel. Never trust these headers on a public listener.
export function getRateLimitIp(req, { tunnelMode = process.env.CLOUDFLARE_TUNNEL_MODE === "true" } = {}) {
  const remote = String(req.socket?.remoteAddress || req.ip || "unknown");
  if (!tunnelMode) return remote;
  const loopback = remote === "127.0.0.1" || remote === "::1" ||
    remote === "::ffff:127.0.0.1";
  if (!loopback) return remote;
  const candidate = req.headers?.["cf-connecting-ip"];
  if (typeof candidate === "string" && isIP(candidate.trim())) return candidate.trim();
  return remote;
}
