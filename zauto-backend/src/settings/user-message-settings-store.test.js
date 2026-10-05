import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

import {
  getUserMessageSettings,
  updateUserMessageSettings,
} from "./user-message-settings-store.js";


function userDir(
  userId
) {
  return path.resolve(
    "data",
    "user-data",
    String(userId)
  );
}


function cleanup(
  userId
) {
  fs.rmSync(
    userDir(userId),
    {
      recursive: true,
      force: true,
    }
  );
}


test(
  "message media settings persist and reload with defaults",
  () => {
    const userId =
      `test-message-settings-${process.pid}`;

    cleanup(
      userId
    );

    try {
      const defaults =
        getUserMessageSettings(
          userId
        );


      assert.equal(
        defaults.showImages,
        true
      );

      assert.equal(
        defaults.showVoiceMessages,
        true
      );


      const saved =
        updateUserMessageSettings(
          userId,
          {
            showImages: false,
            showVoiceMessages: false,
          }
        );


      assert.equal(
        saved.showImages,
        false
      );

      assert.equal(
        saved.showVoiceMessages,
        false
      );


      const raw =
        JSON.parse(
          fs.readFileSync(
            path.join(
              userDir(userId),
              "message-settings.json"
            ),
            "utf8"
          )
        );


      assert.equal(
        raw.showImages,
        false
      );

      assert.equal(
        raw.showVoiceMessages,
        false
      );
    } finally {
      cleanup(
        userId
      );
    }
  }
);
