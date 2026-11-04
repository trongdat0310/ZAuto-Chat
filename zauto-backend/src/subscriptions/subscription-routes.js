import { Router } from "express";
import { acceptUserMessage } from "../messages/user-message-service.js";
import { broadcastUserEvent } from "../realtime/ws-server.js";
import { requireAuth } from "../auth/auth-middleware.js";
import { findUserById, getAllUsers } from "../users/user-store.js";
import { acceptUserChatMessage } from "../conversations/chat-accept-service.js";
import { subscriptionService as store } from "./subscription-service.js";
import { isSubscriptionAdmin } from "./admin-policy.js";
import { createSubscriptionAdmin } from "./subscription-admin-core.js";
import { getAcceptedTripHistory, projectAcceptedTrip, notifySubscriptionChanged } from "./acceptance-history-service.js";

const admin = createSubscriptionAdmin({ store, findUser: findUserById, listUsers: getAllUsers });
export const subscriptionRouter = Router();
subscriptionRouter.use(requireAuth);
subscriptionRouter.get("/plans", (req, res) => res.json({ success: true, plans: store.listPlans() }));
subscriptionRouter.get("/me", (req, res) => res.json({ success: true,
  isAdmin: isSubscriptionAdmin(req.user), subscription: store.getSubscription(req.user.id) }));
subscriptionRouter.get("/me/usage/:feature", (req, res) => res.json({ success: true,
  usage: store.getUsageStatus(req.user.id, req.params.feature) }));
subscriptionRouter.get("/me/history", (req, res) => res.json({ success: true,
  messages: getAcceptedTripHistory(req.user.id) }));

subscriptionRouter.post("/trips/:id/accept", async (req, res) => {
  const result = await acceptUserMessage(req.user.id, req.params.id, req.body?.replyText ?? "Nh\u1eadn");
  try { broadcastUserEvent(req.user.id, "trip_accepted", { messageId: req.params.id }); }
  catch { /* The ledger already holds the external success. */ }
  notifySubscriptionChanged(req.user.id);
  res.json({ success: true, ...result, usage: store.getUsageStatus(req.user.id, "trip_screen_accept") });
});

// Dedicated receive action; ordinary conversation send/reply remains unmetered.
subscriptionRouter.post("/chat/accept", async (req, res) => {
  const result = await acceptUserChatMessage(req.user.id, {
    groupId: req.body?.groupId, msgId: req.body?.msgId ?? null,
    cliMsgId: req.body?.cliMsgId ?? null, replyText: req.body?.replyText,
  });
  res.json({ success: true, ...result, usage: store.getUsageStatus(req.user.id, "chat_accept") });
});
subscriptionRouter.use("/admin", (req, res, next) => {
  if (!isSubscriptionAdmin(req.user)) return res.status(403).json({ success: false,
    code: "ADMIN_REQUIRED", error: "Chi Admin duoc thuc hien thao tac nay." });
  next();
});
subscriptionRouter.get("/admin/users", (req, res) => res.json({ success: true, ...admin.search(req.user, req.query) }));
subscriptionRouter.get("/admin/users/:id", (req, res) => res.json({ success: true, ...admin.detail(req.user, req.params.id) }));
function command(action) {
  return (req, res) => {
    const result = admin.execute(req.user, req.params.id, action, req.body);
    let historySyncPending = false;
    if (action === "reconcile" && result.status === "succeeded") {
      try { projectAcceptedTrip(req.params.id, { ...result.context, ...result.result }); }
      catch { historySyncPending = true; }
    }
    notifySubscriptionChanged(req.params.id);
    res.json({ success: true, item: result, historySyncPending });
  };
}
subscriptionRouter.post("/admin/users/:id/plan", command("assign"));
subscriptionRouter.post("/admin/users/:id/renew", command("renew"));
subscriptionRouter.delete("/admin/users/:id/plan", command("revoke"));
subscriptionRouter.post("/admin/users/:id/resolve", command("reconcile"));
subscriptionRouter.get("/admin/logs", (req, res) => res.json({ success: true, logs: admin.logs(req.user, req.query.userId) }));
subscriptionRouter.use((error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = Number.isInteger(error.status) && error.status >= 400 && error.status <= 599 ? error.status : 500;
  if (status >= 500) console.error("[SUBSCRIPTIONS]", error.code || error.name);
  return res.status(status).json({ success: false, code: error.code || "SUBSCRIPTION_ERROR",
    error: status === 500 ? "Khong the xu ly yeu cau. Vui long thu lai sau." : error.message });
});
