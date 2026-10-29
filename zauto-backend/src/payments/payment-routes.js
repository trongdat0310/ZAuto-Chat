import { Router } from "express";
import { subscriptionService as store } from "../subscriptions/subscription-service.js";
import { findUserByPhone, findUserById } from "../users/user-store.js";
import { notifySubscriptionChanged } from "../subscriptions/acceptance-history-service.js";
import { createPaymentHandlers } from "./payment-handlers.js";

const handlers = createPaymentHandlers({ store, findUserByPhone, findUserById,
  notify: notifySubscriptionChanged });
export const paymentRouter = Router();
paymentRouter.get("/catalog", handlers.catalog);
paymentRouter.post("/orders", handlers.createOrder);
paymentRouter.get("/orders/:id", handlers.orderStatus);
// server.js already mounts this with express.raw BEFORE express.json().
export const sepayWebhook = handlers.webhook;
