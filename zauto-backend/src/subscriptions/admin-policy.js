// Bind an existing account by immutable server-side ID, not by a self-registered phone.
// Resolve the requested phone 0911111111 on the server with scripts/find-admin-user.js.
export function isSubscriptionAdmin(user, env = process.env) {
  const id = String(env.ADMIN_USER_ID || "").trim();
  return Boolean(id && user && user.id === id);
}
