import test from "node:test";
import assert from "node:assert/strict";
import { isSessionCurrent } from "./session-version.js";

test("accepts legacy account and legacy token before session rotation", () => {
  assert.equal(isSessionCurrent({ id: "u1" }, { sub: "u1" }), true);
});

test("accepts newly issued token after password change", () => {
  assert.equal(isSessionCurrent({ sessionVersion: "new" }, { sv: "new" }), true);
});

test("rejects all previous tokens after password change or recovery", () => {
  assert.equal(isSessionCurrent({ sessionVersion: "new" }, { sv: "old" }), false);
  assert.equal(isSessionCurrent({ sessionVersion: "new" }, {}), false);
});

test("rejects missing user or token", () => {
  assert.equal(isSessionCurrent(null, { sv: "v" }), false);
  assert.equal(isSessionCurrent({ sessionVersion: "v" }, null), false);
});
