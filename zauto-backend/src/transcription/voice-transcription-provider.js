const DEFAULT_MODEL =
  process.env.OPENAI_TRANSCRIPTION_MODEL?.trim() ||
  "gpt-4o-mini-transcribe";

const MAX_AUDIO_BYTES =
  Math.max(
    1_000_000,
    Number(
      process.env.VOICE_TRANSCRIPTION_MAX_BYTES
    ) || 20_000_000
  );

const DOWNLOAD_TIMEOUT_MS =
  Math.max(
    5_000,
    Number(
      process.env.VOICE_TRANSCRIPTION_DOWNLOAD_TIMEOUT_MS
    ) || 20_000
  );

const API_TIMEOUT_MS =
  Math.max(
    10_000,
    Number(
      process.env.VOICE_TRANSCRIPTION_API_TIMEOUT_MS
    ) || 45_000
  );


function timeoutSignal(
  milliseconds
) {
  return AbortSignal.timeout(
    milliseconds
  );
}


function audioFileName(
  contentType
) {
  const type =
    String(
      contentType ?? ""
    ).toLowerCase();

  if (type.includes("mp4")) {
    return "voice.m4a";
  }

  if (type.includes("mpeg")) {
    return "voice.mp3";
  }

  if (type.includes("ogg")) {
    return "voice.ogg";
  }

  if (type.includes("wav")) {
    return "voice.wav";
  }

  if (type.includes("webm")) {
    return "voice.webm";
  }

  return "voice.m4a";
}


async function downloadAudio(
  url
) {
  const response =
    await fetch(
      url,
      {
        signal:
          timeoutSignal(
            DOWNLOAD_TIMEOUT_MS
          ),
      }
    );


  if (!response.ok) {
    throw new Error(
      `AUDIO_DOWNLOAD_${response.status}`
    );
  }


  const declaredLength =
    Number(
      response.headers.get(
        "content-length"
      )
    );


  if (
    Number.isFinite(
      declaredLength
    ) &&
    declaredLength >
      MAX_AUDIO_BYTES
  ) {
    throw new Error(
      "AUDIO_TOO_LARGE"
    );
  }


  const buffer =
    await response.arrayBuffer();


  if (
    buffer.byteLength >
    MAX_AUDIO_BYTES
  ) {
    throw new Error(
      "AUDIO_TOO_LARGE"
    );
  }


  const contentType =
    response.headers.get(
      "content-type"
    ) ||
    "audio/mp4";


  return {
    bytes:
      buffer,

    contentType,

    fileName:
      audioFileName(
        contentType
      ),
  };
}


export function isVoiceTranscriptionConfigured() {
  return Boolean(
    process.env.OPENAI_API_KEY?.trim()
  );
}


export async function transcribeVoiceUrl(
  mediaUrl,
  {
    language = "vi",
  } = {}
) {
  const apiKey =
    process.env.OPENAI_API_KEY?.trim();


  if (!apiKey) {
    throw new Error(
      "OPENAI_API_KEY_MISSING"
    );
  }


  const safeUrl =
    String(
      mediaUrl ?? ""
    ).trim();


  if (!safeUrl) {
    throw new Error(
      "VOICE_URL_MISSING"
    );
  }


  const audio =
    await downloadAudio(
      safeUrl
    );


  const form =
    new FormData();


  form.append(
    "model",
    DEFAULT_MODEL
  );


  if (language) {
    form.append(
      "language",
      language
    );
  }


  form.append(
    "file",
    new Blob(
      [audio.bytes],
      {
        type:
          audio.contentType,
      }
    ),
    audio.fileName
  );


  const response =
    await fetch(
      "https://api.openai.com/v1/audio/transcriptions",
      {
        method:
          "POST",

        headers: {
          Authorization:
            `Bearer ${apiKey}`,
        },

        body:
          form,

        signal:
          timeoutSignal(
            API_TIMEOUT_MS
          ),
      }
    );


  const raw =
    await response.text();


  let data =
    null;


  try {
    data =
      JSON.parse(
        raw
      );
  } catch {
    data =
      null;
  }


  if (!response.ok) {
    const message =
      data?.error?.message ??
      raw ??
      `HTTP_${response.status}`;

    throw new Error(
      `TRANSCRIPTION_API_ERROR: ${message}`
    );
  }


  const text =
    String(
      data?.text ?? ""
    ).trim();


  if (!text) {
    throw new Error(
      "TRANSCRIPTION_EMPTY"
    );
  }


  return {
    text,

    model:
      DEFAULT_MODEL,
  };
}
