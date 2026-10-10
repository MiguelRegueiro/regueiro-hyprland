#!/usr/bin/env python3

import asyncio
import json
import os
import signal
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from provider import DEFAULT_PROVIDER, DEFAULT_RATE, DEFAULT_VOICE, synthesize_to_file


ROOT = Path(__file__).resolve().parent
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/regueiro-{os.getuid()}")) / "regueiro-easytts"
STATE = RUNTIME / "state.json"
PREFERENCES = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "regueiro-easytts" / "preferences.json"
DEFAULT_SELECTION_RATE = "+50%"
VALID_PROVIDERS = {"edge", "kokoro"}
VALID_VOICES = {
    "kokoro-michael", "kokoro-onyx",
    "en-US-ChristopherNeural", "en-US-RogerNeural", "en-US-GuyNeural",
    "en-US-AndrewMultilingualNeural",
}


def default_voice_for(provider):
    if provider == "edge":
        return "en-US-AndrewMultilingualNeural"
    return "kokoro-michael"


def compatible_voice(provider, voice):
    # Omitted fields are normal for the lightweight /api/speak command used
    # by F7.  They mean "keep the selected preference", not an invalid voice.
    if not isinstance(voice, str):
        return False
    if provider == "edge":
        return voice.startswith("en-US-")
    return voice.startswith("kokoro-")


def load_preferences():
    """Load the UI's last selected voice and rate, with sane first-run defaults."""
    preferences = {"provider": DEFAULT_PROVIDER, "voice": DEFAULT_VOICE, "rate": DEFAULT_SELECTION_RATE}
    try:
        stored = json.loads(PREFERENCES.read_text(encoding="utf-8"))
        if stored.get("voice") in VALID_VOICES:
            preferences["voice"] = stored["voice"]
        if stored.get("provider") in VALID_PROVIDERS:
            preferences["provider"] = stored["provider"]
        if isinstance(stored.get("rate"), str) and stored["rate"]:
            preferences["rate"] = stored["rate"]
    except (OSError, ValueError, TypeError):
        pass
    if not compatible_voice(preferences["provider"], preferences["voice"]):
        preferences["voice"] = default_voice_for(preferences["provider"])
    return preferences


def save_preferences(provider, voice, rate):
    PREFERENCES.parent.mkdir(parents=True, exist_ok=True)
    temporary = PREFERENCES.with_suffix(".tmp")
    temporary.write_text(json.dumps({"provider": provider, "voice": voice, "rate": rate}), encoding="utf-8")
    temporary.replace(PREFERENCES)


def server_addresses():
    """Return loopback plus the optional Tailscale interface for EasyTTS."""
    host = os.environ.get("EASYTTS_HOST")
    port = int(os.environ.get("EASYTTS_PORT", "8765"))

    if host:
        return [(host, port)]

    addresses = [("127.0.0.1", port)]
    try:
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            check=True,
            capture_output=True,
            text=True,
        )
        tailnet_host = result.stdout.strip().splitlines()[0]
        addresses.append((tailnet_host, port))
    except (FileNotFoundError, IndexError, subprocess.CalledProcessError):
        print("  Tailscale IPv4 not found; listening locally only.")
        print("  Start Tailscale, then restart EasyTTS to share it on your tailnet.")

    return addresses


async def synthesize(text, voice, rate, provider):
    started = time.perf_counter()

    RUNTIME.mkdir(parents=True, exist_ok=True)
    output = RUNTIME / f"http-{threading.get_ident()}-{time.time_ns()}.mp3"
    try:
        await synthesize_to_file(text, output, voice, rate, provider)
        audio = output.read_bytes()
    finally:
        output.unlink(missing_ok=True)

    elapsed = time.perf_counter() - started

    print(
        f"  {len(text):4d} chars"
        f"  → {len(audio) / 1024:6.0f} KiB"
        f"  → {elapsed:5.2f}s"
    )

    return bytes(audio)


def remove_orphaned_audio():
    """A restart cannot replay a previous process's audio, so do not retain it."""
    RUNTIME.mkdir(parents=True, exist_ok=True)
    for pattern in ("speech-*.mp3", "http-*.mp3"):
        for audio_file in RUNTIME.glob(pattern):
            audio_file.unlink(missing_ok=True)


class SpeechController:
    """One short-lived, headless playback job at a time.

    ffplay is deliberately only an audio decoder/output process: it has no
    window, no persistent daemon, and exits at the end of each reading.
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.job = 0
        self.player = None
        self.paused = False
        self.audio_file = None
        self.text = ""
        self.duration = 0.0
        self.position = 0.0
        self.playback_started = None
        self.replay_ready = False
        self.state = "idle"
        self.detail = ""
        preferences = load_preferences()
        self.voice = preferences["voice"]
        self.rate = preferences["rate"]
        self.provider = preferences["provider"]
        remove_orphaned_audio()
        self.write_state("idle")

    def current_position(self):
        if self.playback_started is None:
            return self.position
        return min(self.duration, max(0.0, time.monotonic() - self.playback_started))

    def write_state(self, state, detail=""):
        self.state = state
        self.detail = detail
        payload = json.dumps({"state": state, "text": self.text, "detail": detail,
                              "position": self.current_position(), "duration": self.duration,
                              "replayReady": self.replay_ready,
                              "provider": self.provider, "voice": self.voice, "rate": self.rate})
        temporary = STATE.with_suffix(".tmp")
        temporary.write_text(payload, encoding="utf-8")
        temporary.replace(STATE)

    def snapshot(self):
        with self.lock:
            return {"state": self.state, "text": self.text,
                    "detail": self.detail,
                    "position": self.current_position(), "duration": self.duration,
                    "replayReady": self.replay_ready,
                    "provider": self.provider, "voice": self.voice, "rate": self.rate}

    def set_preferences(self, provider=None, voice=None, rate=None):
        with self.lock:
            if provider in VALID_PROVIDERS:
                self.provider = provider
            if compatible_voice(self.provider, voice):
                self.voice = voice
            elif provider in VALID_PROVIDERS:
                self.voice = default_voice_for(self.provider)
            if isinstance(rate, str) and rate:
                self.rate = rate
            save_preferences(self.provider, self.voice, self.rate)
            self.write_state(self.state, self.detail)

    def _terminate_player(self):
        if self.player and self.player.poll() is None:
            if self.paused:
                self.player.send_signal(signal.SIGCONT)
            self.player.terminate()
        self.player = None
        self.paused = False
        self.playback_started = None

    def _start_player(self, job, position, paused=False):
        player = subprocess.Popen(
            ["ffplay", "-nodisp", "-autoexit", "-loglevel", "error", "-ss", f"{position:.3f}", str(self.audio_file)],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if paused:
            player.send_signal(signal.SIGSTOP)
        self.player = player
        self.paused = paused
        self.position = position
        self.playback_started = None if paused else time.monotonic() - position
        threading.Thread(target=self._wait_for_player, args=(job, player), daemon=True).start()

    def _wait_for_player(self, job, player):
        player.wait()
        with self.lock:
            if job != self.job or player != self.player:
                return
            # EOF is not the same thing as clearing the current reading. Keep
            # its file and duration available, rewound and paused, so Play can
            # immediately replay it without synthesizing the clipboard again.
            self.player = None
            self.paused = False
            self.position = 0.0
            self.playback_started = None
            self.replay_ready = True
            self._start_player(job, 0.0, paused=True)
            self.write_state("paused", "Ready to replay")

    def speak(self, text, provider=None, voice=None, rate=None):
        with self.lock:
            self.provider = provider if provider in VALID_PROVIDERS else self.provider
            self.voice = voice if compatible_voice(self.provider, voice) else default_voice_for(self.provider)
            self.rate = rate if isinstance(rate, str) and rate else self.rate
            save_preferences(self.provider, self.voice, self.rate)
            self.job += 1
            job = self.job
            self.replay_ready = False
            self._terminate_player()
            if self.audio_file:
                self.audio_file.unlink(missing_ok=True)
                self.audio_file = None
            self.text = text
            self.duration = 0.0
            self.position = 0.0
            self.write_state("generating", "Preparing speech")
        threading.Thread(target=self._run, args=(job, text, self.provider, self.voice, self.rate), daemon=True).start()

    def toggle(self):
        """Pause/resume the current reading without a persistent player."""
        with self.lock:
            if not self.player or self.player.poll() is not None:
                return False
            if self.paused:
                self.player.send_signal(signal.SIGCONT)
                self.paused = False
                self.replay_ready = False
                self.playback_started = time.monotonic() - self.position
                self.write_state("playing", "Reading")
            else:
                self.position = self.current_position()
                self.player.send_signal(signal.SIGSTOP)
                self.paused = True
                self.playback_started = None
                self.write_state("paused", "Paused")
            return True

    def cancel(self):
        """Cancel synthesis or stop a current reading."""
        with self.lock:
            self.job += 1
            self.replay_ready = False
            self._terminate_player()
            if self.audio_file:
                self.audio_file.unlink(missing_ok=True)
                self.audio_file = None
            self.text = ""
            self.duration = 0.0
            self.position = 0.0
            self.write_state("idle")

    def reset(self):
        """Return the current audio to its start, ready but not playing."""
        with self.lock:
            if not self.audio_file or not self.audio_file.is_file():
                return False
            self.job += 1
            self.replay_ready = False
            self._terminate_player()
            self._start_player(self.job, 0.0, paused=True)
            self.write_state("paused", "Paused")
            return True

    def seek(self, position):
        with self.lock:
            if not self.audio_file or not self.audio_file.is_file():
                return False
            self.job += 1
            self.replay_ready = False
            paused = self.paused
            self._terminate_player()
            position = min(self.duration, max(0.0, float(position)))
            self._start_player(self.job, position, paused=paused)
            self.write_state("paused" if paused else "playing", "Paused" if paused else "Reading")
            return True

    def _current(self, job):
        with self.lock:
            return job == self.job

    def _run(self, job, text, provider, voice, rate):
        audio_file = RUNTIME / f"speech-{job}.mp3"
        try:
            asyncio.run(synthesize_to_file(text, audio_file, voice, rate, provider))
            if not self._current(job):
                audio_file.unlink(missing_ok=True)
                return
            with self.lock:
                self.audio_file = audio_file
                if job != self.job:
                    return
                probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(audio_file)], check=True, capture_output=True, text=True)
                self.duration = float(probe.stdout.strip())
                self.position = 0.0
                self._start_player(job, 0.0)
                self.write_state("playing", "Reading")
        except Exception as exc:
            print("TTS playback error:", exc)
            if self._current(job):
                self.write_state("error", str(exc))
        finally:
            # Keep the completed audio only while it is the current reading;
            # reset needs it to return to 0:00 without another network call.
            if self.audio_file != audio_file:
                audio_file.unlink(missing_ok=True)


speech = SpeechController()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def send_bytes(self, data, content_type, status=200):
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            # The browser canceled a still-generating request.
            pass

    def send_json(self, obj, status=200):
        data = json.dumps(obj).encode()
        self.send_bytes(
            data,
            "application/json; charset=utf-8",
            status,
        )

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self.send_bytes(
                (ROOT / "index.html").read_bytes(),
                "text/html; charset=utf-8",
            )
            return

        if self.path in ("/favicon.ico", "/favicon.png"):
            self.send_bytes(
                (ROOT / "favicon.png").read_bytes(),
                "image/png",
            )
            return

        if self.path == "/api/status":
            self.send_json(speech.snapshot())
            return

        self.send_error(404)

    def do_POST(self):
        if self.path not in ("/api/tts", "/api/speak", "/api/control"):
            self.send_error(404)
            return

        try:
            length = int(
                self.headers.get("Content-Length", 0)
            )

            payload = json.loads(
                self.rfile.read(length)
            )

            if self.path == "/api/control":
                action = payload.get("action")
                if action == "settings":
                    speech.set_preferences(payload.get("provider"), payload.get("voice"), payload.get("rate"))
                    self.send_json(speech.snapshot())
                    return
                if action == "cancel":
                    speech.cancel()
                    self.send_json({"state": "idle"})
                    return
                if action == "reset":
                    if not speech.reset():
                        self.send_json({"error": "Nothing is ready to reset"}, 409)
                        return
                    self.send_json({"state": "paused"})
                    return
                if action == "seek":
                    if not speech.seek(payload.get("position", 0)):
                        self.send_json({"error": "Nothing is ready to seek"}, 409)
                        return
                    self.send_json(speech.snapshot())
                    return
                if action != "toggle" or not speech.toggle():
                    self.send_json({"error": "Nothing is being read"}, 409)
                    return
                self.send_json({"state": "toggled"})
                return

            text = payload.get("text", "").strip()
            voice = payload.get("voice", DEFAULT_VOICE)
            rate = payload.get("rate", DEFAULT_RATE)
            provider = payload.get("provider", DEFAULT_PROVIDER)

            if not text:
                self.send_json(
                    {"error": "Empty text"},
                    400,
                )
                return

            if self.path == "/api/speak":
                speech.speak(text, payload.get("provider"), payload.get("voice"), payload.get("rate"))
                self.send_json({"state": "generating"}, 202)
                return

            # The Web UI sends short parallel preview requests rather than a
            # /api/speak job.  Keep their provider/model choice persistent so
            # the F7/QuickShell client uses the same local backend next time.
            speech.set_preferences(provider, voice, rate)
            audio = asyncio.run(
                synthesize(
                    text,
                    voice,
                    rate,
                    provider,
                )
            )

            self.send_bytes(
                audio,
                "audio/mpeg",
            )

        except Exception as exc:
            print("TTS error:", exc)

            self.send_json(
                {"error": str(exc)},
                500,
            )


if __name__ == "__main__":
    addresses = server_addresses()

    print()
    print("  EasyTTS")
    for host, port in addresses:
        print(f"  http://{host}:{port}")
    print()
    print("  Parallel chunk mode")
    print("  Ctrl+C to stop")
    print()

    servers = [ThreadingHTTPServer(address, Handler) for address in addresses]
    for server in servers[1:]:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    servers[0].serve_forever()
