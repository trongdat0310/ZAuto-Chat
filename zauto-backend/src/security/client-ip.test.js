import test from "node:test";
import assert from "node:assert/strict";
import { getRateLimitIp } from "./client-ip.js";

function req(remoteAddress, header) {
  return { socket: { remoteAddress }, headers: { "cf-connecting-ip": header } };
}

test("ignores spoofed Cloudflare header outside tunnel mode", () => {
  assert.equal(getRateLimitIp(req("203.0.113.5", "198.51.100.4"), { tunnelMode: false }), "203.0.113.5");
});

test("accepts valid Cloudflare visitor IP only over loopback in tunnel mode", () => {
  assert.equal(getRateLimitIp(req("127.0.0.1", "198.51.100.4"), { tunnelMode: true }), "198.51.100.4");
  assert.equal(getRateLimitIp(req("::1", "2001:db8::2"), { tunnelMode: true }), "2001:db8::2");
  assert.equal(getRateLimitIp(req("203.0.113.5", "198.51.100.4"), { tunnelMode: true }), "203.0.113.5");
});

test("rejects invalid or multi-valued visitor headers", () => {
  assert.equal(getRateLimitIp(req("127.0.0.1", "not-an-ip"), { tunnelMode: true }), "127.0.0.1");
  assert.equal(getRateLimitIp(req("127.0.0.1", "198.51.100.4, 10.0.0.1"), { tunnelMode: true }), "127.0.0.1");
});
