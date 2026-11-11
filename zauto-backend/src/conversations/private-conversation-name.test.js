import test from "node:test";
import assert from "node:assert/strict";
import { resolvePrivatePeerName } from "./private-conversation-name.js";

test("outgoing private message cannot rename chat to current account's name", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", senderId: "self", senderName: "My own Zalo name",
    isSelf: true,
  }), "Người dùng Zalo");
});

test("incoming message can supply a matching peer's display name", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", senderId: "peer", senderName: "Tên đối phương", isSelf: false,
  }), "Tên đối phương");
});

test("profile fetched by peer ID corrects a previously wrong stored name", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", peerName: "Tên Zalo thật",
    senderId: "self", senderName: "My own Zalo name",
    isSelf: true, storedName: "My own Zalo name",
  }), "Tên Zalo thật");
});

test("sender of another thread never supplies the private peer title", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", senderId: "another", senderName: "Sai người",
    isSelf: false, storedName: "Tên đã lưu",
  }), "Tên đã lưu");
});

test("when profile is unavailable the stored peer name is preserved", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", senderId: "self", senderName: "Tên tôi",
    isSelf: true, storedName: "Tên trước đó",
  }), "Tên trước đó");
});

test("blank profile name does not erase a valid known name", () => {
  assert.equal(resolvePrivatePeerName({
    peerId: "peer", peerName: "  ",
    senderId: "peer", senderName: "  ",
    storedName: "Tên đã lưu",
  }), "Tên đã lưu");
});
