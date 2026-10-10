"""The EasyTTS speech-provider boundary.

Only this module knows which service turns text into audio.  Replacing Edge
TTS with a local engine later should require implementing ``synthesize_to_file``
with the same arguments; the HTTP API, clipboard command, and Quickshell OSD
do not need to change.
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import threading
from pathlib import Path

import edge_tts


DEFAULT_VOICE = "kokoro-michael"
DEFAULT_RATE = "+0%"
DEFAULT_PROVIDER = "kokoro"
ROOT = Path(__file__).resolve().parent
KOKORO_PYTHON = ROOT / ".kokoro" / "bin" / "python"
KOKORO_WORKER = ROOT / "kokoro_worker.py"


class LocalWorker:
    """Serialize local synthesis through one warm subprocess."""

    def __init__(self, name: str, python: Path, worker: Path):
        self.name = name
        self.python = python
        self.worker = worker
        self.lock = threading.Lock()
        self.process = None
        self.idle_timer = None

    def _start(self):
        if self.idle_timer:
            self.idle_timer.cancel()
            self.idle_timer = None
        if not self.python.is_file():
            raise RuntimeError(f"{self.name} is not installed.")
        self.process = subprocess.Popen(
            [str(self.python), str(self.worker)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True, bufsize=1,
            env={**os.environ, "TOKENIZERS_PARALLELISM": "false"},
        )
        message = self._read_message()
        if not message.get("ready"):
            self._stop()
            raise RuntimeError(message.get("error", f"{self.name} worker failed to start"))

    def _read_message(self):
        assert self.process and self.process.stdout
        while True:
            line = self.process.stdout.readline()
            if not line:
                raise RuntimeError(f"{self.name} worker exited unexpectedly")
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue

    def _stop(self):
        if self.idle_timer:
            self.idle_timer.cancel()
            self.idle_timer = None
        if self.process:
            self.process.terminate()
            self.process = None

    def _stop_after_idle(self):
        with self.lock:
            self._stop()

    def synthesize(self, text: str, destination: Path, voice: str, rate: str):
        with self.lock:
            if self.idle_timer:
                self.idle_timer.cancel()
                self.idle_timer = None
            if not self.process or self.process.poll() is not None:
                self._start()
            try:
                assert self.process and self.process.stdin
                self.process.stdin.write(json.dumps({"text": text, "output": str(destination), "voice": voice, "rate": rate}) + "\n")
                self.process.stdin.flush()
                result = self._read_message()
                if not result.get("ok"):
                    raise RuntimeError(result.get("error", f"{self.name} synthesis failed"))
                # Playback uses the completed MP3, not the model. Keep the
                # worker briefly for the next contiguous chunk, then release
                # CUDA memory even if the desktop service remains running.
                self.idle_timer = threading.Timer(5, self._stop_after_idle)
                self.idle_timer.daemon = True
                self.idle_timer.start()
            except Exception:
                self._stop()
                raise


KOKORO = LocalWorker("Kokoro", KOKORO_PYTHON, KOKORO_WORKER)


async def synthesize_to_file(
    text: str,
    destination: Path,
    voice: str = DEFAULT_VOICE,
    rate: str = DEFAULT_RATE,
    provider: str = DEFAULT_PROVIDER,
) -> None:
    """Generate an MP3 file with the selected, replaceable speech provider."""
    if provider == "kokoro":
        await asyncio.to_thread(KOKORO.synthesize, text, destination, voice, rate)
        return
    if provider != "edge":
        raise ValueError(f"Unknown speech provider: {provider}")

    communicate = edge_tts.Communicate(text, voice, rate=rate)
    with destination.open("wb") as audio:
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.write(chunk["data"])
