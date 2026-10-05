import json
import os
import sys


def load_model():
    from faster_whisper import WhisperModel

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

    model = WhisperModel(
        model_name,
        device=device,
        compute_type=compute_type,
        cpu_threads=cpu_threads,
    )

    return model, model_name


def transcribe(model, model_name, audio, language):
    segments, info = model.transcribe(
        audio,
        language=language or None,
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

    return {
        "text": " ".join(parts).strip(),
        "model": model_name,
        "language": getattr(
            info,
            "language",
            language,
        ),
    }


def emit(payload):
    sys.stdout.write(
        json.dumps(
            payload,
            ensure_ascii=False,
        )
        + "\n"
    )
    sys.stdout.flush()


def main():
    try:
        model, model_name = load_model()
    except Exception as exc:
        emit({
            "type": "fatal",
            "error": str(exc),
        })
        raise SystemExit(1)

    emit({
        "type": "ready",
        "model": model_name,
    })

    for raw_line in sys.stdin:
        raw_line = raw_line.strip()

        if not raw_line:
            continue

        job_id = None

        try:
            job = json.loads(raw_line)
            job_id = job.get("id")
            audio = str(
                job.get("audio") or ""
            ).strip()
            language = str(
                job.get("language") or "vi"
            ).strip()

            if not audio:
                raise ValueError(
                    "audio path is required"
                )

            result = transcribe(
                model,
                model_name,
                audio,
                language,
            )

            emit({
                "type": "result",
                "id": job_id,
                **result,
            })

        except Exception as exc:
            emit({
                "type": "error",
                "id": job_id,
                "error": str(exc),
            })


if __name__ == "__main__":
    main()
