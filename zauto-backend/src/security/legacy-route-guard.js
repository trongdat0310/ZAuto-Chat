// Legacy endpoints use process-global Zalo data instead of user-scoped stores.
// Do not expose them to authenticated users either: JWT alone cannot provide
// tenant isolation. Modern /api/me/* and /api/subscriptions/* remain available.
export const blockedLegacyPrefixes = Object.freeze([
  "/api/zalo/status",
  "/api/groups",
  "/api/filters",
  "/api/messages",
  "/api/devices",
]);

export function legacyRouteGuard(req, res, next) {
  const path = req.path;
  if (!blockedLegacyPrefixes.some(prefix => path === prefix || path.startsWith(prefix + "/"))) {
    return next();
  }
  return res.status(410).json({
    success: false,
    code: "LEGACY_ENDPOINT_DISABLED",
    error: "Endpoint cu khong con duoc ho tro. Vui long cap nhat ung dung.",
  });
}
