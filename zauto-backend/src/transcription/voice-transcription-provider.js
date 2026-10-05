import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {
  spawn,
} from "node:child_process";


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

const PROCESS_TIMEOUT_MS =
  Math.max(
    30_000,
    Number(
      process.env.VOICE_TRANSCRIPTION_PROCESS_TIMEOUT_MS
    ) || 180_000
  );

const PYTHON_COMMAND =
  process.env.VOICE_TRANSCRIPTION_PYTHON?.trim() ||
  (
    process.platform === "win32"
      ? "python"
      : "python3"
  );

const WORKER_PATH =
  new URL(
    "./local_whisper_worker.py",
    import.meta.url
  );


function timeoutSignal(
  milliseconds
) {
  return AbortSignal.timeout(
    milliseconds
  );
}


function audioExtension(
  contentType,
  mediaUrl
) {
  const type =
    String(
      contentType ?? ""
    ).toLowerCase();

  if (type.includes("mpeg")) {
    return ".mp3";
  }

  if (type.includes("ogg")) {
    return ".ogg";
  }

  if (type.includes("wav")) {
    return ".wav";
  }

  if (type.includes("webm")) {
    return ".webm";
  }

  if (
    type.includes("mp4") ||
    type.includes("m4a")
  ) {
    return ".m4a";
  }


  try {
    const extension =
      path.extname(
        new URL(
          mediaUrl
        ).pathname
      )
        .toLowerCase();

    if (
      [
        ".m4a",
        ".mp3",
        ".ogg",
        ".wav",
        ".webm",
        ".mp4",
      ].includes(
        extension
      )
    ) {
      return extension;
    }
  } catch (_) {
    // Ignore invalid URL here.
  }


  return ".m4a";
}


async function downloadAudioToTemp(
  mediaUrl
) {
  const response =
    await fetch(
      mediaUrl,
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
    Buffer.from(
      await response.arrayBuffer()
    );


  if (
    buffer.byteLength >
    MAX_AUDIO_BYTES
  ) {
    throw new Error(
      "AUDIO_TOO_LARGE"
    );
  }


  const extension =
    audioExtension(
      response.headers.get(
        "content-type"
      ),
      mediaUrl
    );


  const filePath =
    path.join(
      os.tmpdir(),
      `zauto-voice-${crypto.randomUUID()}${extension}`
    );


  await fs.promises.writeFile(
    filePath,
    buffer
  );


  return filePath;
}


function runLocalWhisper(
  filePath,
  language
) {
  return new Promise(
    (
      resolve,
      reject
    ) => {
      const child =
        spawn(
          PYTHON_COMMAND,
          [
            WORKER_PATH.pathname,
            "--audio",
            filePath,
            "--language",
            language || "vi",
          ],
          {
            windowsHide:
              true,

            stdio: [
              "ignore",
              "pipe",
              "pipe",
            ],
          }
        );


      let stdout =
        "";

      let stderr =
        "";

      let settled =
        false;


      const finishReject =
        error => {
          if (settled) {
            return;
          }

          settled =
            true;

          reject(
            error
          );
        };


      const timer =
        setTimeout(
          () => {
            child.kill();

            finishReject(
              new Error(
                "LOCAL_TRANSCRIPTION_TIMEOUT"
              )
            );
          },
          PROCESS_TIMEOUT_MS
        );


      child.stdout.on(
        "data",
        chunk => {
          stdout +=
            chunk.toString();
        }
      );


      child.stderr.on(
        "data",
        chunk => {
          stderr +=
            chunk.toString();
        }
      );


      child.on(
        "error",
        error => {
          clearTimeout(
            timer
          );

          finishReject(
            new Error(
              `LOCAL_TRANSCRIPTION_START_FAILED: ${error.message}`
            )
          );
        }
      );


      child.on(
        "close",
        code => {
          clearTimeout(
            timer
          );


          if (settled) {
            return;
          }


          if (code !== 0) {
            finishReject(
              new Error(
                `LOCAL_TRANSCRIPTION_FAILED: ${stderr.trim() || `exit ${code}`}`
              )
            );

            return;
          }


          try {
            const data =
              JSON.parse(
                stdout.trim()
              );


            const text =
              String(
                data?.text ?? ""
              ).trim();


            if (!text) {
              finishReject(
                new Error(
                  "TRANSCRIPTION_EMPTY"
                )
              );

              return;
            }


            settled =
              true;

            resolve({
              text,

              model:
                data.model ??
                "local-whisper",

              language:
                data.language ??
                language ??
                "vi",
            });

          } catch (error) {

            finishReject(
              new Error(
                `LOCAL_TRANSCRIPTION_INVALID_OUTPUT: ${error.message}`
              )
            );
          }
        }
      );
    }
  );
}


export function isVoiceTranscriptionConfigured() {
  return true;
}


export async function transcribeVoiceUrl(
  mediaUrl,
  {
    language = "vi",
  } = {}
) {
  const safeUrl =
    String(
      mediaUrl ?? ""
    ).trim();


  if (!safeUrl) {
    throw new Error(
      "VOICE_URL_MISSING"
    );
  }


  let filePath =
    null;


  try {
    filePath =
      await downloadAudioToTemp(
        safeUrl
      );


    return await runLocalWhisper(
      filePath,
      language
    );

  } finally {

    if (filePath) {
      await fs.promises
        .unlink(
          filePath
        )
        .catch(
          () => {}
        );
    }
  }
}
