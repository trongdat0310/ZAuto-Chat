import test from "node:test";
import assert from "node:assert/strict";

// Import smoke test: the unlink route must not break server startup with
// missing exports or circular references.
process.env.JWT_SECRET ??= "unlink-service-import-test";
process.env.ZALO_SESSION_KEY ??= "00".repeat(32);
const { unlinkUserZalo } = await import("./user-zalo-unlink-service.js");

test("production unlink entry point imports all dependencies", () => {
  assert.equal(typeof unlinkUserZalo, "function");
});
