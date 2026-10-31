import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import {
  extractOrderCode, isOrderId, verifySePaySignature, transactionFingerprint,
} from "./payment-security.js";

// Test-only codes: never POST these fixtures to a live payment endpoint.
const A = "ZCA7A1234567890ABCDEF";
const B = "ZCA8B1234567890ABCDEF";
const OTHER_A = "ZCA7B1234567890ABCDEF";
const memo = id => `NHAN TU TEST TRACE 5000 ${id} CHUYEN TIEN`;

test("fixtures contain full 18-character hexadecimal suffixes", () => {
  for (const id of [A, B, OTHER_A]) assert.equal(isOrderId(id), true);
});

test("ZCA7 metadata cannot hide the full code in the original bank content", () => {
  assert.equal(extractOrderCode({ content: memo(A), code: "ZCA7" }), A);
});
test("ZCA8 metadata cannot hide another full code", () => {
  assert.equal(extractOrderCode({ content: memo(B), code: "ZCA8" }), B);
});
for (let length = 1; length < 18; length++) {
  test(`a ${length}-character suffix prefix requires a full code in content`, () => {
    const partial = A.slice(0, 3 + length);
    assert.equal(extractOrderCode({ content: memo(A), code: partial }), A);
    assert.equal(extractOrderCode({ content: partial, code: partial }), null);
    assert.equal(extractOrderCode({ content: "Chuyen tien", code: partial }), null);
  });
}
test("lowercase original content and metadata work", () => {
  assert.equal(extractOrderCode({ content: memo(A).toLowerCase(), code: "zca7" }), A);
});
test("full metadata and full content still must agree", () => {
  assert.equal(extractOrderCode({ content: memo(A), code: A }), A);
  assert.equal(extractOrderCode({ content: memo(A), code: B }), null);
  assert.equal(extractOrderCode({ content: memo(A), code: OTHER_A }), null);
});
test("unrelated short codes remain rejected", () => {
  for (const code of ["ZCA8", "ZCA7B", "DH7", "ZCA", "ZCA7G", " ZCA7", "ZCA7 "]) {
    assert.equal(extractOrderCode({ content: memo(A), code }), null);
  }
});
test("partial code alone cannot identify a paid order", () => {
  for (const code of ["ZCA7", "ZCA8", "ZCA"]) {
    assert.equal(extractOrderCode({ content: code, code }), null);
    assert.equal(extractOrderCode({ content: code, code: null }), null);
  }
});
test("two distinct full codes stay ambiguous even with a matching short prefix", () => {
  for (const code of [null, "ZCA7", A]) {
    assert.equal(extractOrderCode({ content: `${A} ${B}`, code }), null);
  }
});
test("duplicates of the same full code are not a second order", () => {
  assert.equal(extractOrderCode({ content: `${A} - ${A}`, code: "ZCA7" }), A);
});
test("a full code embedded in another alphanumeric token is not matched", () => {
  for (const content of ["X" + A, A + "F", A + "0", A + "X", A.slice(0, -1)]) {
    assert.equal(extractOrderCode({ content, code: "ZCA7" }), null);
  }
});
test("spaces inside the code are not silently removed", () => {
  assert.equal(extractOrderCode({ content: A.slice(0, 8) + " " + A.slice(8), code: "ZCA7" }), null);
});
test("existing exact full-provider-code fallback is preserved", () => {
  assert.equal(extractOrderCode({ content: "bank memo", code: A }), A);
});
test("absent or empty metadata allows a full code in content", () => {
  for (const code of [null, "", undefined]) {
    assert.equal(extractOrderCode({ content: memo(A), code }), A);
  }
});
test("short metadata never bypasses HMAC authentication", () => {
  const raw = Buffer.from(JSON.stringify({ content: memo(A), code: "ZCA7" }));
  const now = 1793458800000;
  const timestamp = String(Math.floor(now / 1000));
  const secret = "unit-test-prefix-secret-not-for-production";
  const signature = "sha256=" + crypto.createHmac("sha256", secret)
    .update(timestamp + ".").update(raw).digest("hex");
  const headers = { "x-sepay-timestamp": timestamp, "x-sepay-signature": signature };
  assert.doesNotThrow(() => verifySePaySignature(raw, headers, secret, now));
  assert.throws(() => verifySePaySignature(raw, {}, secret, now), { code: "INVALID_SIGNATURE" });
  assert.throws(() => verifySePaySignature(raw, headers, secret + "wrong", now), { code: "INVALID_SIGNATURE" });
  assert.throws(() => verifySePaySignature(Buffer.from(raw.toString().replace("ZCA7", "ZCA8")), headers, secret, now),
    { code: "INVALID_SIGNATURE" });
});
test("changing provider code still changes a stored receipt fingerprint", () => {
  const tx = { id: 1, gateway: "VPBank", accountNumber: "1234567890",
    transactionDate: "2026-10-31 22:00:00", transferType: "in", transferAmount: 139000,
    content: memo(A), code: "ZCA7", referenceCode: "TEST" };
  assert.notEqual(transactionFingerprint(tx), transactionFingerprint({ ...tx, code: A }));
});
