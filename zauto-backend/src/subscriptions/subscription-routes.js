import { Router } from "express";
import { requireAuth } from "../auth/auth-middleware.js";
import { findUserById, getAllUsers } from "../users/user-store.js";
import { acceptUserChatMessage } from "../conversations/chat-accept-service.js";
import { subscriptionService as store, subscriptionError } from "./subscription-service.js";
import { isSubscriptionAdmin } from "./admin-policy.js";

export const subscriptionRouter = Router();
subscriptionRouter.use(requireAuth);
subscriptionRouter.get("/plans", (req, res) => res.json({ success: true, plans: store.listPlans() }));
subscriptionRouter.get("/me", (req, res) => res.json({ success: true,
  isAdmin: isSubscriptionAdmin(req.user), subscription: store.getSubscription(req.user.id) }));
subscriptionRouter.get("/me/usage/:feature", (req, res) => res.json({ success: true,
  usage: store.getUsageStatus(req.user.id, req.params.feature) }));

// Dedicated receive action. The ordinary /messages/send endpoint is untouched.
// Client-supplied userId, feature, uidFrom, mentions and senderName are never used.
subscriptionRouter.post("/chat/accept", async (req, res) => {
  const result = await acceptUserChatMessage(req.user.id, {
    groupId: req.body?.groupId, msgId: req.body?.msgId ?? null,
    cliMsgId: req.body?.cliMsgId ?? null, replyText: req.body?.replyText,
  });
  res.json({ success: true, ...result, usage: store.getUsageStatus(req.user.id, "chat_accept") });
});
subscriptionRouter.use("/admin", (req, res, next) => {
  if (!isSubscriptionAdmin(req.user)) return res.status(403).json({ success: false, code: "ADMIN_REQUIRED", error: "Chi Admin duoc thuc hien thao tac nay." });
  next();
});
subscriptionRouter.get("/admin/users", (req, res) => {
  const q = String(req.query.q || "").trim().toLowerCase().slice(0, 100);
  const users = getAllUsers().filter(u => !q || String(u.phone).includes(q) || String(u.name).toLowerCase().includes(q));
  res.json({ success: true, users: users.slice(0, 100).map(({ id, name, phone }) => ({ id, name, phone })) });
});
subscriptionRouter.param("id", (req, res, next, id) => {
  if (!findUserById(id)) return next(subscriptionError("USER_NOT_FOUND", "Khong tim thay tai khoan.", 404));
  next();
});
subscriptionRouter.get("/admin/users/:id", (req, res) => res.json({ success: true,
  subscription: store.getSubscription(req.params.id), pending: store.getPendingOperations(req.params.id) }));
subscriptionRouter.post("/admin/users/:id/plan", (req, res) => res.json({ success: true,
  item: store.assignPlan({ userId: req.params.id, planId: req.body?.planId,
    months: req.body?.months ?? 1, actorId: req.user.id }) }));
subscriptionRouter.delete("/admin/users/:id/plan", (req, res) => {
  store.revokePlan({ userId: req.params.id, actorId: req.user.id });
  res.json({ success: true });
});
subscriptionRouter.post("/admin/users/:id/resolve", (req, res) => res.json({ success: true,
  operation: store.resolveUncertain({ userId: req.params.id, targetKey: req.body?.targetKey,
    outcome: req.body?.outcome, note: req.body?.note, actorId: req.user.id }) }));
subscriptionRouter.get("/admin/logs", (req, res) => res.json({ success: true, logs: store.getAuditLogs() }));
subscriptionRouter.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = Number.isInteger(error.status) ? error.status : 500;
  if (status >= 500) console.error("[SUBSCRIPTIONS]", error.code || error.name);
  return res.status(status).json({ success: false, code: error.code || "SUBSCRIPTION_ERROR",
    error: status === 500 ? "Khong the xu ly yeu cau. Vui long thu lai sau." : error.message });
});
