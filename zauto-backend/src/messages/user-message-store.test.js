import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  fileURLToPath,
} from "node:url";

import {
  clearUserMessageCache,
  disableUserMessageStoreTestMetrics,
  flushUserMessages,
  getUserMessageStoreTestMetrics,
  getUserMessages,
  resetUserMessageStoreTestMetrics,
  saveUserMessage,
} from "./user-message-store.js";


const __filename =
  fileURLToPath(
    import.meta.url
  );

const __dirname =
  path.dirname(
    __filename
  );


function userDir(
  userId
) {
  return path.resolve(
    __dirname,
    "../../data/user-data",
    String(userId)
  );
}


function cleanup(
  userId
) {
  clearUserMessageCache(
    userId
  );

  fs.rmSync(
    userDir(
      userId
    ),
    {
      recursive: true,
      force: true,
    }
  );
}


test(
  "new trips are visible from RAM before disk flush",
  async () => {
    const userId =
      `test-message-store-ram-${process.pid}`;

    cleanup(
      userId
    );

    resetUserMessageStoreTestMetrics();

    try {
      const first =
        saveUserMessage(
          userId,
          {
            groupId: "group-a",
            senderId: "sender-a",
            zaloMessageId: "msg-1",
            content: "Cuốc 1",
          }
        );

      assert.equal(
        first.created,
        true
      );

      const messages =
        getUserMessages(
          userId,
          10
        );

      assert.equal(
        messages.length,
        1
      );

      assert.equal(
        messages[0].id,
        first.message.id
      );

      const filePath =
        path.join(
          userDir(userId),
          "messages.json"
        );

      assert.equal(
        fs.existsSync(filePath),
        false
      );

      await flushUserMessages(
        userId
      );

      assert.equal(
        fs.existsSync(filePath),
        true
      );

      const saved =
        JSON.parse(
          fs.readFileSync(
            filePath,
            "utf-8"
          )
        );

      assert.equal(
        saved.length,
        1
      );

      assert.equal(
        saved[0].id,
        first.message.id
      );
    } finally {
      disableUserMessageStoreTestMetrics();

      await flushUserMessages(
        userId
      );

      cleanup(
        userId
      );
    }
  }
);


test(
  "multiple trips in one tick coalesce into one persistence snapshot",
  async () => {
    const userId =
      `test-message-store-coalesce-${process.pid}`;

    cleanup(
      userId
    );

    resetUserMessageStoreTestMetrics();

    try {
      saveUserMessage(
        userId,
        {
          groupId: "group-a",
          senderId: "sender-a",
          zaloMessageId: "msg-1",
          content: "Cuốc 1",
        }
      );

      saveUserMessage(
        userId,
        {
          groupId: "group-a",
          senderId: "sender-b",
          zaloMessageId: "msg-2",
          content: "Cuốc 2",
        }
      );

      await flushUserMessages(
        userId
      );

      const metrics =
        getUserMessageStoreTestMetrics();

      assert.equal(
        metrics.persistCalls,
        1
      );

      const saved =
        JSON.parse(
          fs.readFileSync(
            path.join(
              userDir(userId),
              "messages.json"
            ),
            "utf-8"
          )
        );

      assert.equal(
        saved.length,
        2
      );

      assert.equal(
        saved[0].content,
        "Cuốc 2"
      );

      assert.equal(
        saved[1].content,
        "Cuốc 1"
      );
    } finally {
      disableUserMessageStoreTestMetrics();

      await flushUserMessages(
        userId
      );

      cleanup(
        userId
      );
    }
  }
);


test(
  "message cache avoids repeated disk reads",
  async () => {
    const userId =
      `test-message-store-cache-${process.pid}`;

    cleanup(
      userId
    );

    fs.mkdirSync(
      userDir(userId),
      {
        recursive: true,
      }
    );

    fs.writeFileSync(
      path.join(
        userDir(userId),
        "messages.json"
      ),
      JSON.stringify(
        [
          {
            id: "stored-1",
            content: "Persisted",
          },
        ]
      ),
      "utf-8"
    );

    resetUserMessageStoreTestMetrics();

    try {
      const first =
        getUserMessages(
          userId,
          10
        );

      const second =
        getUserMessages(
          userId,
          10
        );

      assert.equal(
        first.length,
        1
      );

      assert.equal(
        second.length,
        1
      );

      const metrics =
        getUserMessageStoreTestMetrics();

      assert.equal(
        metrics.diskReadCalls,
        1
      );
    } finally {
      disableUserMessageStoreTestMetrics();

      cleanup(
        userId
      );
    }
  }
);



test(
  "trip keeps source quote snapshot in RAM before conversation persistence",
  async () => {
    const userId =
      `test-message-store-quote-${process.pid}`;

    cleanup(
      userId
    );


    try {
      const saved =
        saveUserMessage(
          userId,
          {
            groupId:
              "group-a",

            senderId:
              "sender-a",

            zaloMessageId:
              "msg-quote-1",

            clientMessageId:
              "cli-quote-1",

            content:
              "Q1 di Noi Bai 650k",

            sourceQuote: {
              content:
                "Q1 di Noi Bai 650k",

              msgType:
                "chat.text",

              uidFrom:
                "sender-a",

              msgId:
                "msg-quote-1",

              cliMsgId:
                "cli-quote-1",

              ts:
                123456,

              ttl:
                0,
            },
          }
        );


      assert.equal(
        saved.created,
        true
      );

      assert.equal(
        saved.message
          .sourceQuote
          .msgId,
        "msg-quote-1"
      );

      assert.equal(
        saved.message
          .sourceQuote
          .cliMsgId,
        "cli-quote-1"
      );

      assert.equal(
        saved.message
          .sourceQuote
          .content,
        "Q1 di Noi Bai 650k"
      );


      const fromRam =
        getUserMessages(
          userId,
          10
        )[0];


      assert.equal(
        fromRam
          .sourceQuote
          .msgId,
        "msg-quote-1"
      );

    } finally {
      await flushUserMessages(
        userId
      );

      cleanup(
        userId
      );
    }
  }
);

test(
  "trip history supports group date and content filters",
  async () => {
    const userId =
      `test-message-history-filter-${process.pid}`;

    cleanup(
      userId
    );


    try {
      const first =
        saveUserMessage(
          userId,
          {
            groupId:
              "group-a",

            groupName:
              "Nhóm A",

            senderId:
              "sender-a",

            senderName:
              "Tài xế A",

            zaloMessageId:
              "history-1",

            content:
              "Đón khách sân bay",
          }
        );


      const second =
        saveUserMessage(
          userId,
          {
            groupId:
              "group-b",

            groupName:
              "Nhóm B",

            senderId:
              "sender-b",

            senderName:
              "Tài xế B",

            zaloMessageId:
              "history-2",

            content:
              "Cuốc đi trung tâm",
          }
        );


      first.message.receivedAt =
        "2026-10-06T02:00:00.000Z";

      second.message.receivedAt =
        "2026-10-07T03:00:00.000Z";


      const byGroup =
        getUserMessages(
          userId,
          {
            limit:
              100,

            groupId:
              "group-a",
          }
        );


      assert.deepEqual(
        byGroup.map(
          item =>
            item.content
        ),
        [
          "Đón khách sân bay",
        ]
      );


      const byDate =
        getUserMessages(
          userId,
          {
            limit:
              100,

            from:
              "2026-10-07T00:00:00.000Z",

            to:
              "2026-10-07T23:59:59.999Z",
          }
        );


      assert.deepEqual(
        byDate.map(
          item =>
            item.content
        ),
        [
          "Cuốc đi trung tâm",
        ]
      );


      const byContent =
        getUserMessages(
          userId,
          {
            limit:
              100,

            q:
              "SÂN BAY",
          }
        );


      assert.deepEqual(
        byContent.map(
          item =>
            item.content
        ),
        [
          "Đón khách sân bay",
        ]
      );


      const combined =
        getUserMessages(
          userId,
          {
            limit:
              100,

            groupId:
              "group-a",

            q:
              "khách",
          }
        );


      assert.equal(
        combined.length,
        1
      );

    } finally {
      await flushUserMessages(
        userId
      );

      cleanup(
        userId
      );
    }
  }
);

