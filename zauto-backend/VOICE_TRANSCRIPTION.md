# Voice transcription - local Whisper

ZAuto transcribes voice messages locally with `faster-whisper`.
There is no per-minute transcription API charge and no OpenAI API key is used.

## Install

Python 3.10+ is recommended.

Windows:

    py -m pip install -r requirements-transcription.txt

If your `python` command does not point to the same Python installation, set:

    VOICE_TRANSCRIPTION_PYTHON=C:\\Path\\To\\python.exe

The first transcription starts a persistent Python worker and loads the model.
On the first run, faster-whisper downloads the selected model files to the
machine. Later jobs reuse the same loaded model.

## Default CPU configuration

    VOICE_TRANSCRIPTION_MODEL=small
    VOICE_TRANSCRIPTION_DEVICE=cpu
    VOICE_TRANSCRIPTION_COMPUTE_TYPE=int8
    VOICE_TRANSCRIPTION_CONCURRENCY=1

The defaults are designed to avoid competing with the realtime Node backend.

Optional:

    VOICE_TRANSCRIPTION_CPU_THREADS=0
    VOICE_TRANSCRIPTION_MAX_BYTES=20000000
    VOICE_TRANSCRIPTION_DOWNLOAD_TIMEOUT_MS=20000
    VOICE_TRANSCRIPTION_PROCESS_TIMEOUT_MS=180000

## NVIDIA GPU

For a compatible CUDA setup you can use:

    VOICE_TRANSCRIPTION_DEVICE=cuda
    VOICE_TRANSCRIPTION_COMPUTE_TYPE=float16

Then increase concurrency only after measuring server load.

## Runtime behavior

- Voice is stored and broadcast to Flutter before transcription begins.
- Transcription runs asynchronously outside the realtime message path.
- The model stays loaded in one persistent Python worker.
- Temporary audio files are deleted after each job.
- Turning off "Phiên âm tin nhắn thoại" prevents new transcription jobs.
- Turning off "Hiển thị tin nhắn thoại" also disables transcription.
- Transcripts are stored on the existing message and pushed to Flutter with
  `conversation_message_updated`.
