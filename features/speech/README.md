# Speech

Speech features live together here, with text-to-speech and speech-to-text
kept as separate tools:

- [`tts/`](tts/README.md) — Triton TTS, the browser interface and shared
  speech playback service.
- [`stt/`](stt/README.md) — local dictation and speech recognition.

Their runtime services and settings remain independent. This directory groups
the capabilities without making either tool depend on the other.
