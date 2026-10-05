"""The EasyTTS speech-provider boundary.

Only this module knows which service turns text into audio.  Replacing Edge
TTS with a local engine later should require implementing ``synthesize_to_file``
with the same arguments; the HTTP API, clipboard command, and Quickshell OSD
do not need to change.
"""

from __future__ import annotations

from pathlib import Path

import edge_tts


DEFAULT_VOICE = "en-US-AndrewMultilingualNeural"
DEFAULT_RATE = "+0%"


async def synthesize_to_file(
    text: str,
    destination: Path,
    voice: str = DEFAULT_VOICE,
    rate: str = DEFAULT_RATE,
) -> None:
    """Generate an MP3 file from text using the configured provider."""
    communicate = edge_tts.Communicate(text, voice, rate=rate)
    with destination.open("wb") as audio:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.write(chunk["data"])
