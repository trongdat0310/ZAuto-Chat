import {
  getUserMessageSettings,
} from "../settings/user-message-settings-store.js";

import {
  updateConversationMessageTranscription,
} from "../conversations/conversation-store.js";

import {
  broadcastUserEvent,
} from "../realtime/ws-server.js";

import {
  transcribeVoiceUrl,
} from "./voice-transcription-provider.js";


const MAX_CONCURRENCY =
  Math.max(
    1,
    Math.min(
      4,
      Number(
        process.env.VOICE_TRANSCRIPTION_CONCURRENCY
      ) || 1
    )
  );


const queue =
  [];

const pendingKeys =
  new Set();

let activeCount =
  0;


function jobKey(
  userId,
  message
) {
  return [
    String(userId),
    String(
      message?.groupId ?? ""
    ),
    String(
      message?.id ??
      message?.msgId ??
      message?.cliMsgId ??
      ""
    ),
  ].join(":");
}


function broadcastUpdated(
  userId,
  message
) {
  if (!message) {
    return;
  }


  broadcastUserEvent(
    userId,
    "conversation_message_updated",
    {
      groupId:
        message.groupId,

      message,
    }
  );
}


async function processJob(
  job
) {
  const {
    userId,
    message,
  } = job;


  const settings =
    getUserMessageSettings(
      userId
    );


  if (
    settings.showVoiceMessages !==
      true ||
    settings.transcribeVoiceMessages !==
      true
  ) {
    return;
  }


  const processing =
    updateConversationMessageTranscription(
      userId,
      message.groupId,
      {
        id:
          message.id,

        msgId:
          message.msgId,

        cliMsgId:
          message.cliMsgId,

        status:
          "processing",

        error:
          null,
      }
    );


  broadcastUpdated(
    userId,
    processing
  );


  try {
    const result =
      await transcribeVoiceUrl(
        message.mediaUrl,
        {
          language:
            "vi",
        }
      );


    const updated =
      updateConversationMessageTranscription(
        userId,
        message.groupId,
        {
          id:
            message.id,

          msgId:
            message.msgId,

          cliMsgId:
            message.cliMsgId,

          transcript:
            result.text,

          status:
            "completed",

          error:
            null,
        }
      );


    broadcastUpdated(
      userId,
      updated
    );

  } catch (error) {

    const updated =
      updateConversationMessageTranscription(
        userId,
        message.groupId,
        {
          id:
            message.id,

          msgId:
            message.msgId,

          cliMsgId:
            message.cliMsgId,

          status:
            "failed",

          error:
            error?.message ??
            String(error),
        }
      );


    broadcastUpdated(
      userId,
      updated
    );


    console.warn(
      "[VOICE TRANSCRIPTION] FAILED:",
      userId,
      message.groupId,
      error?.message ??
      error
    );
  }
}


function pump() {
  while (
    activeCount <
      MAX_CONCURRENCY &&
    queue.length > 0
  ) {
    const job =
      queue.shift();


    activeCount += 1;


    Promise.resolve()
      .then(
        () =>
          processJob(
            job
          )
      )
      .catch(
        error => {
          console.error(
            "[VOICE TRANSCRIPTION] JOB ERROR:",
            error
          );
        }
      )
      .finally(
        () => {
          activeCount -= 1;

          pendingKeys.delete(
            job.key
          );

          pump();
        }
      );
  }
}


export function enqueueVoiceTranscription(
  userId,
  message
) {
  if (
    !message ||
    message.mediaType !==
      "voice" ||
    !message.mediaUrl
  ) {
    return false;
  }


  if (
    message.transcriptionStatus ===
      "completed" &&
    message.transcript
  ) {
    return false;
  }


  const settings =
    getUserMessageSettings(
      userId
    );


  if (
    settings.showVoiceMessages !==
      true ||
    settings.transcribeVoiceMessages !==
      true
  ) {
    return false;
  }


  const key =
    jobKey(
      userId,
      message
    );


  if (
    pendingKeys.has(
      key
    )
  ) {
    return false;
  }


  pendingKeys.add(
    key
  );


  queue.push({
    key,

    userId:
      String(userId),

    message: {
      ...message,
    },
  });


  pump();


  return true;
}


export function getVoiceTranscriptionQueueStats() {
  return {
    active:
      activeCount,

    queued:
      queue.length,

    pending:
      pendingKeys.size,

    concurrency:
      MAX_CONCURRENCY,
  };
}
