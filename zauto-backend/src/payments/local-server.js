import "dotenv/config";
import { subscriptionService as store } from "../subscriptions/subscription-service.js";
import { findUserByPhone, findUserById } from "../users/user-store.js";
import { paymentConfig } from "./payment-config.js";
import { createPaymentHandlers } from "./payment-handlers.js";
import { createPaymentGateway } from "./payment-gateway.js";

try {
  paymentConfig(); // Fail before exposing an unconfigured receiver.
  const port = Number(process.env.PAYMENT_PORT || 3001);
  if (!Number.isInteger(port) || port < 1024 || port > 65535) throw Error("Invalid PAYMENT_PORT");
  const server = createPaymentGateway({ handlers: createPaymentHandlers({ store, findUserByPhone, findUserById }) });
  server.on("error", error => { console.error("[PAYMENT GATEWAY]", error.code || error.message); process.exitCode = 1; });
  server.listen(port, "127.0.0.1", () => {
    console.log(`[PAYMENTS] Checkout: http://127.0.0.1:${port}/checkout`);
    console.log(`[PAYMENTS] Tunnel this port only: ${port}. Keep the main app port private.`);
  });
  for (const signal of ["SIGINT", "SIGTERM"]) {
    process.once(signal, () => server.close(() => process.exit(0)));
  }
} catch (error) {
  console.error("[PAYMENT CONFIG]", error.message);
  process.exitCode = 1;
}
