import test from "node:test";
import assert from "node:assert/strict";

import {
  isPhotoConversationEvent,
  isVoiceConversationEvent,
  shouldDisplayConversationEvent,
} from "./message-media-policy.js";


function message(
  msgType,
  content = {}
) {
  return {
    data: {
      msgType,
      content,
    },
  };
}


test(
  "photo settings hide current and legacy photo types",
  () => {
    const settings = {
      showImages: false,
      showVoiceMessages: true,
    };


    assert.equal(
      isPhotoConversationEvent(
        message("chat.photo")
      ),
      true
    );

    assert.equal(
      isPhotoConversationEvent(
        message(32)
      ),
      true
    );

    assert.equal(
      shouldDisplayConversationEvent(
        settings,
        message("chat.photo")
      ),
      false
    );

    assert.equal(
      shouldDisplayConversationEvent(
        settings,
        message(32)
      ),
      false
    );
  }
);


test(
  "voice settings hide current and legacy voice types",
  () => {
    const settings = {
      showImages: true,
      showVoiceMessages: false,
    };


    for (
      const type of [
        "chat.voice",
        "chat.voice.msg",
        "chat.audio",
        31,
      ]
    ) {
      assert.equal(
        isVoiceConversationEvent(
          message(type)
        ),
        true
      );

      assert.equal(
        shouldDisplayConversationEvent(
          settings,
          message(type)
        ),
        false
      );
    }
  }
);


test(
  "media settings do not hide unrelated message types",
  () => {
    const settings = {
      showImages: false,
      showVoiceMessages: false,
    };


    for (
      const type of [
        "chat.video",
        "chat.video.msg",
        "share.file",
        "chat.file",
        "chat.gif",
      ]
    ) {
      assert.equal(
        shouldDisplayConversationEvent(
          settings,
          message(type)
        ),
        true
      );
    }


    assert.equal(
      shouldDisplayConversationEvent(
        settings,
        {
          data: {
            msgType: "chat.text",
            content: "hello",
          },
        }
      ),
      true
    );
  }
);
