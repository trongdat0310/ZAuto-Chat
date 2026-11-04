import test from "node:test";
import assert from "node:assert/strict";
import { createAuthRateLimiter } from "./auth-rate-limit.js";

function request(limiter, { ip = "127.0.0.1", identity = "user@example.com", path = "/api/auth/login" } = {}) {
  const req = { socket: { remoteAddress: ip }, path, body: { phone: identity } };
  const headers = {};
  let status = null;
  let next = false;
  const res = {
    setHeader(name, value) { headers[name] = value; },
    status(code) { status = code; return this; },
    json(body) { return { status, body }; },
  };
  const result = limiter(req, res, () => { next = true; });
  return { next, result, headers };
}

test("limits repeated requests and returns Retry-After", () => {
  let time = 1000;
  const limiter = createAuthRateLimiter({ max: 2, windowMs: 10000, now: () => time });
  assert.equal(request(limiter).next, true);
  assert.equal(request(limiter).next, true);
  const blocked = request(limiter);
  assert.equal(blocked.result.status, 429);
  assert.equal(blocked.headers["Retry-After"], "10");
  time += 10001;
  assert.equal(request(limiter).next, true);
});

test("separates endpoints and identifiers and does not trust forwarded headers", () => {
  const limiter = createAuthRateLimiter({ max: 1 });
  assert.equal(request(limiter).next, true);
  assert.equal(request(limiter, { path: "/api/auth/register" }).next, true);
  assert.equal(request(limiter, { identity: "other@example.com" }).next, true);
  assert.equal(request(limiter, { ip: "127.0.0.2" }).next, true);
  assert.equal(request(limiter).result.status, 429);
});
