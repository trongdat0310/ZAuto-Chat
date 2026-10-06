import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  fileURLToPath,
} from "node:url";

import {
  deleteUserConversation,
  getUserConversationList,
  getUserConversationMessages,
  getUserConversationMessagesPage,
  markConversationMessageDeletedLocal,
  markUserConversationRead,
  saveConversationMessage,
  setUserConversationPinned,
  syncConversationGroups,
} from "./conversation-store.js";


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


function textMessage({
  groupId,
  msgId,
  cliMsgId,
  content,
  timestamp,
  isSelf = false,
} = {}) {
  return {
    threadId:
      groupId,

    isSelf,

    data: {
      msgId,
      cliMsgId,
      msgType:
        "chat.text",

      content,

      uidFrom:
        isSelf
          ? "self-user"
          : "sender-user",

      ts:
        timestamp,
    },
  };
}


test(
  "pin and unpin persist in conversation list ordering",
  () => {
    const userId =
      `test-conversation-pin-${process.pid}`;

    cleanup(
      userId
    );


    try {
      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-a",

            name:
              "Group A",
          },
          {
            groupId:
              "group-b",

            name:
              "Group B",
          },
        ]
      );


      const pinned =
        setUserConversationPinned(
          userId,
          "group-b",
          true
        );


      assert.equal(
        pinned.pinned,
        true
      );


      let conversations =
        getUserConversationList(
          userId
        );


      assert.equal(
        conversations[0].groupId,
        "group-b"
      );


      const unpinned =
        setUserConversationPinned(
          userId,
          "group-b",
          false
        );


      assert.equal(
        unpinned.pinned,
        false
      );


      conversations =
        getUserConversationList(
          userId
        );


      assert.equal(
        conversations.find(
          item =>
            item.groupId ===
            "group-b"
        )?.pinned,
        false
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);


test(
  "deleted conversation stays hidden after group sync and local history is cleared",
  () => {
    const userId =
      `test-conversation-delete-${process.pid}`;

    cleanup(
      userId
    );


    try {
      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-delete",

            name:
              "Delete Me",
          },
        ]
      );


      saveConversationMessage(
        userId,
        {
          groupName:
            "Delete Me",

          message:
            textMessage({
              groupId:
                "group-delete",

              msgId:
                "msg-before-delete",

              cliMsgId:
                "cli-before-delete",

              content:
                "old history",

              timestamp:
                1_700_000_000_000,
            }),
        }
      );


      assert.equal(
        getUserConversationMessages(
          userId,
          "group-delete"
        ).length,
        1
      );


      const deleted =
        deleteUserConversation(
          userId,
          "group-delete"
        );


      assert.equal(
        deleted.deleted,
        true
      );


      assert.equal(
        getUserConversationList(
          userId
        ).length,
        0
      );


      assert.equal(
        getUserConversationMessages(
          userId,
          "group-delete"
        ).length,
        0
      );


      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-delete",

            name:
              "Delete Me",
          },
        ]
      );


      assert.equal(
        getUserConversationList(
          userId
        ).length,
        0
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);


test(
  "new message revives a locally deleted conversation without restoring old history",
  () => {
    const userId =
      `test-conversation-revive-${process.pid}`;

    cleanup(
      userId
    );


    try {
      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-revive",

            name:
              "Revive Group",
          },
        ]
      );


      saveConversationMessage(
        userId,
        {
          groupName:
            "Revive Group",

          message:
            textMessage({
              groupId:
                "group-revive",

              msgId:
                "msg-old",

              cliMsgId:
                "cli-old",

              content:
                "old message",

              timestamp:
                1_700_000_000_000,
            }),
        }
      );


      deleteUserConversation(
        userId,
        "group-revive"
      );


      saveConversationMessage(
        userId,
        {
          groupName:
            "Revive Group",

          message:
            textMessage({
              groupId:
                "group-revive",

              msgId:
                "msg-new",

              cliMsgId:
                "cli-new",

              content:
                "new message",

              timestamp:
                1_700_000_100_000,
            }),
        }
      );


      const conversations =
        getUserConversationList(
          userId
        );


      assert.equal(
        conversations.length,
        1
      );


      assert.equal(
        conversations[0].groupId,
        "group-revive"
      );


      assert.equal(
        conversations[0].lastContent,
        "new message"
      );


      const messages =
        getUserConversationMessages(
          userId,
          "group-revive"
        );


      assert.equal(
        messages.length,
        1
      );


      assert.equal(
        messages[0].msgId,
        "msg-new"
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);


test(
  "deleted local message remains tombstoned when the same realtime message arrives again",
  () => {
    const userId =
      `test-message-delete-tombstone-${process.pid}`;

    cleanup(
      userId
    );


    try {
      const original =
        textMessage({
          groupId:
            "group-message-delete",

          msgId:
            "msg-delete",

          cliMsgId:
            "cli-delete",

          content:
            "delete this",

          timestamp:
            1_700_000_000_000,
        });


      saveConversationMessage(
        userId,
        {
          groupName:
            "Message Delete",

          message:
            original,
        }
      );


      const deleted =
        markConversationMessageDeletedLocal(
          userId,
          "group-message-delete",
          {
            msgId:
              "msg-delete",

            cliMsgId:
              "cli-delete",
          }
        );


      assert.equal(
        deleted.status,
        "deleted_local"
      );


      assert.equal(
        deleted.content,
        null
      );


      const duplicateResult =
        saveConversationMessage(
          userId,
          {
            groupName:
              "Message Delete",

            message:
              original,
          }
        );


      assert.equal(
        duplicateResult.status,
        "deleted_local"
      );


      const messages =
        getUserConversationMessages(
          userId,
          "group-message-delete"
        );


      assert.equal(
        messages.length,
        1
      );


      assert.equal(
        messages[0].status,
        "deleted_local"
      );


      assert.equal(
        messages[0].content,
        null
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);

test(
  "mark read clears unread and the next incoming message becomes unread again",
  () => {
    const userId =
      `test-conversation-read-${process.pid}`;

    cleanup(
      userId
    );


    try {
      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-read",

            name:
              "Read Group",
          },
        ]
      );


      saveConversationMessage(
        userId,
        {
          groupName:
            "Read Group",

          message:
            textMessage({
              groupId:
                "group-read",

              msgId:
                "msg-unread-1",

              cliMsgId:
                "cli-unread-1",

              content:
                "first unread",

              timestamp:
                Date.now() + 1000,
            }),
        }
      );


      let conversation =
        getUserConversationList(
          userId
        )[0];


      assert.equal(
        conversation.unreadCount,
        1
      );


      const read =
        markUserConversationRead(
          userId,
          "group-read"
        );


      assert.equal(
        read.unreadCount,
        0
      );


      conversation =
        getUserConversationList(
          userId
        )[0];


      assert.equal(
        conversation.unreadCount,
        0
      );


      saveConversationMessage(
        userId,
        {
          groupName:
            "Read Group",

          message:
            textMessage({
              groupId:
                "group-read",

              msgId:
                "msg-unread-2",

              cliMsgId:
                "cli-unread-2",

              content:
                "second unread",

              timestamp:
                Date.now() + 5000,
            }),
        }
      );


      conversation =
        getUserConversationList(
          userId
        )[0];


      assert.equal(
        conversation.unreadCount,
        1
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);


test(
  "hidden conversation cannot be pinned by stale device state",
  () => {
    const userId =
      `test-hidden-conversation-pin-${process.pid}`;

    cleanup(
      userId
    );


    try {
      syncConversationGroups(
        userId,
        [
          {
            groupId:
              "group-hidden-pin",

            name:
              "Hidden Pin",
          },
        ]
      );


      deleteUserConversation(
        userId,
        "group-hidden-pin"
      );


      const pinned =
        setUserConversationPinned(
          userId,
          "group-hidden-pin",
          true
        );


      assert.equal(
        pinned,
        null
      );


      assert.equal(
        getUserConversationList(
          userId
        ).length,
        0
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);

test(
  "out of order history insert keeps cursor pagination chronological",
  () => {
    const userId =
      `test-conversation-order-${process.pid}`;

    cleanup(
      userId
    );


    try {
      const groupId =
        "group-order";


      for (
        const [
          id,
          timestamp,
        ]
        of [
          ["3", 3000],
          ["1", 1000],
          ["2", 2000],
          ["4", 4000],
        ]
      ) {
        saveConversationMessage(
          userId,
          {
            groupName:
              "Order Group",

            message:
              textMessage({
                groupId,
                msgId:
                  `msg-${id}`,
                cliMsgId:
                  `cli-${id}`,
                content:
                  id,
                timestamp,
              }),
          }
        );
      }


      const latest =
        getUserConversationMessagesPage(
          userId,
          groupId,
          {
            limit:
              2,
          }
        );


      assert.deepEqual(
        latest.messages.map(
          item =>
            item.content
        ),
        [
          "3",
          "4",
        ]
      );


      const older =
        getUserConversationMessagesPage(
          userId,
          groupId,
          {
            limit:
              2,

            beforeId:
              latest.messages[0].id,
          }
        );


      assert.deepEqual(
        older.messages.map(
          item =>
            item.content
        ),
        [
          "1",
          "2",
        ]
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);

