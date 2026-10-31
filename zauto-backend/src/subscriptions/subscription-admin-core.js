import { subscriptionError } from "./subscription-service.js";
import { isSubscriptionAdmin } from "./admin-policy.js";

const publicUser = ({ id, name, phone }) => ({ id, name, phone });
const normalized = value => String(value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/\u0111/gi, "d").toLowerCase();
function integer(value, fallback, max) {
  if (value === undefined) return fallback;
  if (!/^\d+$/.test(String(value)) || Array.isArray(value)) throw subscriptionError("INVALID_PAGINATION");
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0 || number > max) throw subscriptionError("INVALID_PAGINATION");
  return number;
}

// Authorization lives here too, not only in Express or Flutter. Only allowlisted
// fields reach the store; client actorId/role/userId never change authority.
export function createSubscriptionAdmin({ store, findUser, listUsers, isAdmin = isSubscriptionAdmin }) {
  function authorize(actor) {
    if (!isAdmin(actor)) throw subscriptionError("ADMIN_REQUIRED", "Chi Admin duoc thuc hien thao tac nay.", 403);
  }
  function target(actor, id) {
    authorize(actor);
    const user = findUser(id);
    if (!user) throw subscriptionError("USER_NOT_FOUND", "Khong tim thay tai khoan.", 404);
    return user;
  }
  return {
    search(actor, query = {}) {
      authorize(actor);
      if (query.q !== undefined && typeof query.q !== "string") throw subscriptionError("INVALID_SEARCH");
      const q = normalized(String(query.q || "").trim().slice(0, 100));
      let phone = q.replace(/[^0-9]/g, "");
      if (phone.startsWith("84") && phone.length >= 11) phone = `0${phone.slice(2)}`;
      const offset = integer(query.offset, 0, 1000000);
      const limit = integer(query.limit, 25, 100);
      if (limit === 0) throw subscriptionError("INVALID_PAGINATION");
      const users = listUsers().filter(user => !q || normalized(user.name).includes(q) ||
        (phone && String(user.phone).includes(phone)))
        .sort((a, b) => String(a.phone).localeCompare(String(b.phone)) || String(a.id).localeCompare(String(b.id)));
      return { users: users.slice(offset, offset + limit).map(publicUser), total: users.length,
        offset, limit, hasMore: offset + limit < users.length };
    },
    detail(actor, id) {
      const user = target(actor, id);
      return { user: publicUser(user), subscription: store.getSubscription(id),
        pending: store.getPendingOperations(id), logs: store.getAuditLogs(id) };
    },
    logs(actor, id) {
      authorize(actor);
      if (id !== undefined) target(actor, id);
      return store.getAuditLogs(id);
    },
    execute(actor, id, action, body = {}) {
      target(actor, id);
      if (!body || typeof body !== "object" || Array.isArray(body) ||
          typeof body.requestId !== "string" || !/^[A-Za-z0-9_-]{8,128}$/.test(body.requestId) ||
          typeof body.expectedRevision !== "string" || !/^[a-f0-9]{64}$/.test(body.expectedRevision)) {
        throw subscriptionError("INVALID_ADMIN_COMMAND", "Thieu ma yeu cau hoac phien ban goi. Hay tai lai trang.");
      }
      const common = { userId: id, actorId: actor.id, requestId: body.requestId,
        expectedRevision: body.expectedRevision, note: body.note ?? "" };
      switch (action) {
        case "assign": return store.assignPlan({ ...common, planId: body.planId, months: body.months ?? 1 });
        case "renew": return store.renewPlan({ ...common, months: body.months ?? 1 });
        case "revoke": return store.revokePlan(common);
        case "reconcile": return store.resolveUncertain({ ...common, targetKey: body.targetKey, outcome: body.outcome });
        default: throw subscriptionError("INVALID_ADMIN_ACTION");
      }
    },
  };
}
