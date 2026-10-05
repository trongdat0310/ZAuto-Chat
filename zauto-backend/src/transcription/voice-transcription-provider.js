import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import {
  spawn,
} from "node:child_process";
import {
  fileURLToPath,
} from "node:url";


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
  fileURLToPath(
    new URL(
      "./local_whisper_worker.py",
      import.meta.url
    )
  );


let worker =
  null;

let workerReady =
  false;

let stdoutBuffer =
  "";

let workerStartPromise =
  null;

const pendingJobs =
  new Map();


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
    // Ignore invalid URL.
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


function rejectAllPending(
  error
) {
  for (
    const job of
    pendingJobs.values()
  ) {
    clearTimeout(
      job.timer
    );

    job.reject(
      error
    );
  }


  pendingJobs.clear();
}


function handleWorkerLine(
  line
) {
  let data =
    null;


  try {
    data =
      JSON.parse(
        line
      );
  } catch {
    return;
  }


  if (
    data?.type ===
      "ready"
  ) {
    workerReady =
      true;

    console.log(
      "[VOICE TRANSCRIPTION] Local Whisper ready:",
      data.model
    );

    return;
  }


  if (
    data?.type ===
      "fatal"
  ) {
    rejectAllPending(
      new Error(
        `LOCAL_WHISPER_FATAL: ${data.error ?? "unknown"}`
      )
    );

    return;
  }


  const id =
    String(
      data?.id ?? ""
    );


  const pending =
    pendingJobs.get(
      id
    );


  if (!pending) {
    return;
  }


  pendingJobs.delete(
    id
  );


  clearTimeout(
    pending.timer
  );


  if (
    data.type ===
      "error"
  ) {
    pending.reject(
      new Error(
        `LOCAL_TRANSCRIPTION_FAILED: ${data.error ?? "unknown"}`
      )
    );

    return;
  }


  const text =
    String(
      data?.text ?? ""
    ).trim();


  if (!text) {
    pending.reject(
      new Error(
        "TRANSCRIPTION_EMPTY"
      )
    );

    return;
  }


  pending.resolve({
    text,

    model:
      data.model ??
      "local-whisper",

    language:
      data.language ??
      "vi",
  });
}


function attachWorker(
  child
) {
  child.stdout.on(
    "data",
    chunk => {
      stdoutBuffer +=
        chunk.toString();


      while (
        stdoutBuffer.includes(
          "\n"
        )
      ) {
        const index =
          stdoutBuffer.indexOf(
            "\n"
          );

        const line =
          stdoutBuffer
            .slice(
              0,
              index
            )
            .trim();

        stdoutBuffer =
          stdoutBuffer.slice(
            index + 1
          );


        if (line) {
          handleWorkerLine(
            line
          );
        }
      }
    }
  );


  child.stderr.on(
    "data",
    chunk => {
      const message =
        chunk
          .toString()
          .trim();

      if (message) {
        console.warn(
          "[VOICE TRANSCRIPTION] Python:",
          message
        );
      }
    }
  );


  child.on(
    "error",
    error => {
      workerReady =
        false;

      worker =
        null;

      workerStartPromise =
        null;

      rejectAllPending(
        new Error(
          `LOCAL_TRANSCRIPTION_START_FAILED: ${error.message}`
        )
      );
    }
  );


  child.on(
    "close",
    code => {
      workerReady =
        false;

      worker =
        null;

      workerStartPromise =
        null;

      rejectAllPending(
        new Error(
          `LOCAL_TRANSCRIPTION_WORKER_EXITED: ${code}`
        )
      );
    }
  );
}


async function ensureWorker() {
  if (
    worker &&
    workerReady
  ) {
    return worker;
  }


  if (
    workerStartPromise
  ) {
    return workerStartPromise;
  }


  workerStartPromise =
    new Promise(
      (
        resolve,
        reject
      ) => {
        const child =
          spawn(
            PYTHON_COMMAND,
            [
              WORKER_PATH,
            ],
            {
              windowsHide:
                true,

              stdio: [
                "pipe",
                "pipe",
                "pipe",
              ],
            }
          );


        worker =
          child;

        attachWorker(
          child
        );


        const startedAt =
          Date.now();


        const timer =
          setInterval(
            () => {
              if (
                worker === child &&
                workerReady
              ) {
                clearInterval(
                  timer
                );

                workerStartPromise =
                  null;

                resolve(
                  child
                );

                return;
              }


              if (
                worker !== child
              ) {
                clearInterval(
                  timer
                );

                workerStartPromise =
                  null;

                reject(
                  new Error(
                    "LOCAL_TRANSCRIPTION_WORKER_FAILED"
                  )
                );

                return;
              }


              if (
                Date.now() -
                  startedAt >
                PROCESS_TIMEOUT_MS
              ) {
                clearInterval(
                  timer
                );

                child.kill();

                workerStartPromise =
                  null;

                reject(
                  new Error(
                    "LOCAL_TRANSCRIPTION_WORKER_START_TIMEOUT"
                  )
                );
              }
            },
            50
          );
      }
    );


  return workerStartPromise;
}


async function transcribeLocalFile(
  filePath,
  language
) {
  const child =
    await ensureWorker();


  const id =
    crypto.randomUUID();


  return new Promise(
    (
      resolve,
      reject
    ) => {
      const timer =
        setTimeout(
          () => {
            pendingJobs.delete(
              id
            );

            reject(
              new Error(
                "LOCAL_TRANSCRIPTION_TIMEOUT"
              )
            );
          },
          PROCESS_TIMEOUT_MS
        );


      pendingJobs.set(
        id,
        {
          resolve,
          reject,
          timer,
        }
      );


      child.stdin.write(
        JSON.stringify({
          id,

          audio:
            filePath,

          language:
            language ||
            "vi",
        }) +
        "\n",
        error => {
          if (!error) {
            return;
          }


          const pending =
            pendingJobs.get(
              id
            );


          if (!pending) {
            return;
          }


          pendingJobs.delete(
            id
          );

          clearTimeout(
            pending.timer
          );

          reject(
            new Error(
              `LOCAL_TRANSCRIPTION_WRITE_FAILED: ${error.message}`
            )
          );
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


    return await transcribeLocalFile(
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
