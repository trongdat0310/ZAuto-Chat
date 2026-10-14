import { Router } from "express";
import { requireAuth } from "../auth/auth-middleware.js";
import { findUserById, findUserByPhone, getAllUsers } from "../users/user-store.js";
import { listPlans, getSubscription, getUsageStatus, assignPlan, revokePlan, getAuditLogs } from "./subscription-service.js";

export const subscriptionRouter = Router();
subscriptionRouter.use(requireAuth);
function adminOnly(req, res, next) {
  const phones = (process.env.ADMIN_PHONES || "0911111111").split(",").map(x => x.trim()).filter(Boolean);
  if (!phones.length || !phones.includes(req.user.phone)) return res.status(403).json({ success: false, error: "Admin access required" });
  next();
}
subscriptionRouter.get("/plans", (req, res) => res.json({ success: true, plans: listPlans() }));
subscriptionRouter.get("/me", (req, res) => res.json({ success: true, subscription: getSubscription(req.user.id) }));
subscriptionRouter.get("/me/usage/:feature", (req, res) => {
  if (!/^[a-zA-Z0-9_-]{1,80}$/.test(req.params.feature)) return res.status(400).json({ success: false });
  res.json({ success: true, usage: getUsageStatus(req.user.id, req.params.feature) });
});
subscriptionRouter.use("/admin", adminOnly);
subscriptionRouter.get("/admin/users", (req, res) => {
  const q = String(req.query.q || "").toLowerCase().trim();
  res.json({ success: true, users: getAllUsers().filter(u => !q || u.phone.includes(q) || u.name.toLowerCase().includes(q)).slice(0, 100).map(u => ({ id: u.id, name: u.name, phone: u.phone })) });
});
subscriptionRouter.get("/admin/users/:id", (req, res) => {
  const user = findUserById(req.params.id);
  if (!user) return res.status(404).json({ success: false });
  res.json({ success: true, subscription: getSubscription(user.id) });
});
subscriptionRouter.post("/admin/users/:id/plan", (req, res) => {
  if (!findUserById(req.params.id)) return res.status(404).json({ success: false, error: "User not found" });
  try {
    const item = assignPlan({ userId: req.params.id, planId: req.body?.planId, months: req.body?.months ?? 1, actorId: req.user.id });
    res.json({ success: true, item });
  } catch (error) { res.status(400).json({ success: false, error: error.message }); }
});
subscriptionRouter.delete("/admin/users/:id/plan", (req, res) => {
  if (!findUserById(req.params.id)) return res.status(404).json({ success: false });
  revokePlan({ userId: req.params.id, actorId: req.user.id });
  res.json({ success: true });
});
subscriptionRouter.get("/admin/logs", (req, res) => res.json({ success: true, logs: getAuditLogs() }));
