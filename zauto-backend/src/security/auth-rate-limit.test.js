import test from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { createAuthRateLimiter } from "./auth-rate-limit.js";

function request(limiter, { ip = "127.0.0.1", identity = "user@example.com", path = "/api/auth/login", statusCode = 200 } = {}) {
  const req = { socket: { remoteAddress: ip }, path, body: { phone: identity } };
  const res = new EventEmitter();
  const headers = {};
  let status = null;
  let next = false;
  res.setHeader = (name, value) => { headers[name] = value; };
  res.status = code => { status = code; return res; };
  res.json = body => ({ status, body });
  res.statusCode = statusCode;
  const result = limiter(req, res, () => { next = true; });
  if (next) res.emit("finish");
  return { next, result, headers };
}

test("counts login failures per account, not successful logins", () => {
  let time = 1000;
  const limiter = createAuthRateLimiter({ max: 2, ipMax: 100, failureOnly: true, windowMs: 10000, now: () => time });
  for (let i = 0; i < 20; i++) assert.equal(request(limiter).next, true);
  assert.equal(request(limiter, { statusCode: 401 }).next, true);
  assert.equal(request(limiter, { statusCode: 401 }).next, true);
  const blocked = request(limiter);
  assert.equal(blocked.result.status, 429);
  assert.equal(blocked.headers["Retry-After"], "10");
  time += 10001;
  assert.equal(request(limiter).next, true);
});

test("IP ceiling stops account rotation without trusting forwarded headers", () => {
  const limiter = createAuthRateLimiter({ max: 10, ipMax: 2, failureOnly: true });
  assert.equal(request(limiter, { identity: "a" }).next, true);
  assert.equal(request(limiter, { identity: "b" }).next, true);
  assert.equal(request(limiter, { identity: "c" }).result.status, 429);
  assert.equal(request(limiter, { ip: "127.0.0.2" }).next, true);
});

test("registration and recovery limits are separated by route and identity", () => {
  const limiter = createAuthRateLimiter({ max: 1, ipMax: 10 });
  assert.equal(request(limiter).next, true);
  assert.equal(request(limiter).result.status, 429);
  assert.equal(request(limiter, { path: "/api/auth/register" }).next, true);
  assert.equal(request(limiter, { identity: "other@example.com" }).next, true);
});
