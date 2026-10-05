import argparse
import json
import os
import sys


def emit_error(message):
    sys.stderr.write(str(message) + "\n")
    sys.stderr.flush()
    raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audio", required=True)
    parser.add_argument("--language", default="vi")
    args = parser.parse_args()

    try:
        from faster_whisper import WhisperModel
    except Exception as exc:
        emit_error(
            "faster-whisper is not installed: "
            + str(exc)
        )

    model_name = os.environ.get(
        "VOICE_TRANSCRIPTION_MODEL",
        "small",
    ).strip() or "small"

    device = os.environ.get(
        "VOICE_TRANSCRIPTION_DEVICE",
        "cpu",
    ).strip() or "cpu"

    default_compute = (
        "float16"
        if device == "cuda"
        else "int8"
    )

    compute_type = os.environ.get(
        "VOICE_TRANSCRIPTION_COMPUTE_TYPE",
        default_compute,
    ).strip() or default_compute

    cpu_threads_raw = os.environ.get(
        "VOICE_TRANSCRIPTION_CPU_THREADS",
        "0",
    )

    try:
        cpu_threads = max(
            0,
            int(cpu_threads_raw),
        )
    except ValueError:
        cpu_threads = 0

    try:
        model = WhisperModel(
            model_name,
            device=device,
            compute_type=compute_type,
            cpu_threads=cpu_threads,
        )

        segments, info = model.transcribe(
            args.audio,
            language=args.language or None,
            beam_size=5,
            vad_filter=True,
            condition_on_previous_text=False,
        )

        parts = []

        for segment in segments:
            text = str(
                segment.text or ""
            ).strip()

            if text:
                parts.append(text)

        transcript = " ".join(parts).strip()

        result = {
            "text": transcript,
            "model": model_name,
            "language": getattr(
                info,
                "language",
                args.language,
            ),
        }

        sys.stdout.write(
            json.dumps(
                result,
                ensure_ascii=False,
            )
        )
        sys.stdout.flush()

    except Exception as exc:
        emit_error(exc)


if __name__ == "__main__":
    main()
