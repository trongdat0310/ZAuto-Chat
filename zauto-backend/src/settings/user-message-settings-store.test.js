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



test(
  "legacy transcription setting is removed from persisted settings",
  () => {
    const userId =
      `test-message-settings-legacy-${process.pid}`;

    cleanup(
      userId
    );


    try {
      const directory =
        userDir(
          userId
        );


      fs.mkdirSync(
        directory,
        {
          recursive: true,
        }
      );


      const file =
        path.join(
          directory,
          "message-settings.json"
        );


      fs.writeFileSync(
        file,
        JSON.stringify(
          {
            showImages: true,
            showVoiceMessages: true,
            transcribeVoiceMessages: true,
          },
          null,
          2
        ),
        "utf8"
      );


      const settings =
        getUserMessageSettings(
          userId
        );


      assert.equal(
        Object.prototype.hasOwnProperty.call(
          settings,
          "transcribeVoiceMessages"
        ),
        false
      );


      const saved =
        JSON.parse(
          fs.readFileSync(
            file,
            "utf8"
          )
        );


      assert.equal(
        Object.prototype.hasOwnProperty.call(
          saved,
          "transcribeVoiceMessages"
        ),
        false
      );

    } finally {
      cleanup(
        userId
      );
    }
  }
);
