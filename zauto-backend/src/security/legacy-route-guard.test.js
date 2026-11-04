import test from "node:test";
import assert from "node:assert/strict";
import { legacyRouteGuard } from "./legacy-route-guard.js";

function run(path) {
  let result = null;
  let nextCalled = false;
  const res = {
    status(code) { result = { code }; return this; },
    json(body) { result.body = body; return this; },
  };
  legacyRouteGuard({ path }, res, () => { nextCalled = true; });
  return { result, nextCalled };
}

test("global legacy endpoints are disabled, including nested paths", () => {
  for (const path of ["/api/groups", "/api/groups/1/toggle", "/api/filters", "/api/messages", "/api/messages/1/accept", "/api/messages/1/ignore", "/api/devices/register", "/api/zalo/status"]) {
    const outcome = run(path);
    assert.equal(outcome.result.code, 410, path);
    assert.equal(outcome.result.body.code, "LEGACY_ENDPOINT_DISABLED");
    assert.equal(outcome.nextCalled, false);
  }
});

test("user-scoped, subscription, payment and health routes remain available", () => {
  for (const path of ["/api/me/messages", "/api/me/devices", "/api/subscriptions/me", "/api/payments/catalog", "/api/payments/sepay/webhook", "/api/auth/login", "/health", "/api/messages-v2"]) {
    const outcome = run(path);
    assert.equal(outcome.nextCalled, true, path);
    assert.equal(outcome.result, null);
  }
});
