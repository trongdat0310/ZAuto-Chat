# Voice transcription

Voice transcription is optional and runs asynchronously after the Zalo voice
message has already been stored and broadcast to Flutter.

Required environment variable:

OPENAI_API_KEY=your_api_key_here

Optional environment variables:

OPENAI_TRANSCRIPTION_MODEL=gpt-4o-mini-transcribe
VOICE_TRANSCRIPTION_CONCURRENCY=2
VOICE_TRANSCRIPTION_MAX_BYTES=20000000
VOICE_TRANSCRIPTION_DOWNLOAD_TIMEOUT_MS=20000
VOICE_TRANSCRIPTION_API_TIMEOUT_MS=45000

Behavior:

- If the user disables "Hiển thị tin nhắn thoại", voice messages are hidden and
  transcription is disabled.
- If the user enables voice but disables "Phiên âm tin nhắn thoại", no
  transcription request is made.
- If transcription is enabled but OPENAI_API_KEY is missing, voice playback
  continues normally and the transcript status becomes unavailable.
- Audio download and transcription never block the realtime message path.
