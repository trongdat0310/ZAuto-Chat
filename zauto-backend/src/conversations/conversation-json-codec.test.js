import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { serializeConversationJson } from "./conversation-json-codec.js";

test("message history is compact but round-trips all JSON values unchanged", () => {
  const file = path.join("data", "user-data", "u", "conversations", "messages", "g.json");
  const messages = [{
    id: "id-1",
    content: "Hà Nội → Nội Bài 😄\nNgày mai",
    rawData: { content: 'Tin nhắn "đã xác nhận"', quote: { msgId: "123" } },
    senderAvatar: null,
    timestamp: 1790000000000,
  }];
  const compact = serializeConversationJson(file, messages);
  const pretty = JSON.stringify(messages, null, 2);
  assert.equal(compact, JSON.stringify(messages));
  assert.deepEqual(JSON.parse(compact), JSON.parse(pretty));
  assert.ok(Buffer.byteLength(compact) < Buffer.byteLength(pretty));
  assert.ok(!compact.includes("\n  "));
});

test("conversation indexes retain human readable indentation", () => {
  const file = path.join("data", "user-data", "u", "conversations", "index.json");
  const data = [{ groupId: "g", name: "Nhóm cuốc", unreadCount: 2 }];
  assert.equal(serializeConversationJson(file, data), JSON.stringify(data, null, 2));
});

test("non-message JSON under the same root keeps existing representation", () => {
  const file = path.join("data", "user-data", "u", "conversations", "metadata.json");
  assert.equal(serializeConversationJson(file, { a: 1 }), '{\n  "a": 1\n}');
});
