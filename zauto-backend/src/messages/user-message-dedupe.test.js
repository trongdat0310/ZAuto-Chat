import test from "node:test";
import assert from "node:assert/strict";

import {
  shouldSkipDuplicateUserMessage,
} from "./user-message-dedupe.js";


test(
  "dedupe matches same sender and normalized content inside window",
  () => {
    const userId =
      `dedupe-user-${process.pid}-a`;

    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: "sender-1",
          content: "  Có   cuốc Nội Bài  ",
          windowSeconds: 10,
        }
      ),
      false
    );


    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: "sender-1",
          content: "có cuốc nội bài",
          windowSeconds: 10,
        }
      ),
      true
    );
  }
);


test(
  "dedupe does not merge different senders",
  () => {
    const userId =
      `dedupe-user-${process.pid}-b`;

    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: "sender-1",
          content: "cuốc hà nội 500k",
          windowSeconds: 10,
        }
      ),
      false
    );


    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: "sender-2",
          content: "cuốc hà nội 500k",
          windowSeconds: 10,
        }
      ),
      false
    );
  }
);


test(
  "dedupe does not suppress when sender id is missing",
  () => {
    const userId =
      `dedupe-user-${process.pid}-c`;

    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: null,
          content: "cuốc test",
          windowSeconds: 10,
        }
      ),
      false
    );


    assert.equal(
      shouldSkipDuplicateUserMessage(
        userId,
        {
          senderId: null,
          content: "cuốc test",
          windowSeconds: 10,
        }
      ),
      false
    );
  }
);
