import test from "node:test";
import assert from "node:assert/strict";

import {
  clearConversationSendIdempotencyCache,
  normalizeConversationSendRequestId,
  runConversationSendOnce,
} from "./conversation-send-idempotency.js";


test(
  "same in-flight conversation send request executes only once",
  async () => {
    clearConversationSendIdempotencyCache();

    let calls =
      0;

    let release;

    const gate =
      new Promise(
        resolve => {
          release =
            resolve;
        }
      );


    const executor =
      async () => {
        calls +=
          1;

        await gate;

        return {
          sent:
            true,

          call:
            calls,
        };
      };


    const first =
      runConversationSendOnce(
        "user-a",
        "text-request-1",
        executor
      );


    const second =
      runConversationSendOnce(
        "user-a",
        "text-request-1",
        executor
      );


    assert.equal(
      calls,
      1
    );


    release();


    const [
      firstResult,
      secondResult,
    ] =
      await Promise.all(
        [
          first,
          second,
        ]
      );


    assert.deepEqual(
      firstResult,
      secondResult
    );


    assert.equal(
      calls,
      1
    );
  }
);


test(
  "successful send result is replayed without executing again",
  async () => {
    clearConversationSendIdempotencyCache();

    let calls =
      0;


    const first =
      await runConversationSendOnce(
        "user-a",
        "photo-request-1",
        async () => {
          calls +=
            1;

          return {
            sent:
              true,
          };
        }
      );


    const second =
      await runConversationSendOnce(
        "user-a",
        "photo-request-1",
        async () => {
          calls +=
            1;

          return {
            sent:
              false,
          };
        }
      );


    assert.equal(
      calls,
      1
    );


    assert.deepEqual(
      first,
      second
    );
  }
);


test(
  "failed send is not cached and can retry with the same request id",
  async () => {
    clearConversationSendIdempotencyCache();

    let calls =
      0;


    await assert.rejects(
      () =>
        runConversationSendOnce(
          "user-a",
          "retry-request-1",
          async () => {
            calls +=
              1;

            throw new Error(
              "temporary failure"
            );
          }
        ),
      /temporary failure/
    );


    const result =
      await runConversationSendOnce(
        "user-a",
        "retry-request-1",
        async () => {
          calls +=
            1;

          return {
            sent:
              true,
          };
        }
      );


    assert.equal(
      calls,
      2
    );


    assert.equal(
      result.sent,
      true
    );
  }
);


test(
  "request id validation rejects unsafe values",
  () => {
    assert.equal(
      normalizeConversationSendRequestId(
        "text-abc_123:xyz"
      ),
      "text-abc_123:xyz"
    );


    assert.throws(
      () =>
        normalizeConversationSendRequestId(
          "bad request id"
        ),
      error =>
        error?.code ===
          "INVALID_CLIENT_REQUEST_ID"
    );
  }
);
