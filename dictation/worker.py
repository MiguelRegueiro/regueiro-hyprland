#!/usr/bin/env python3
"""Reliable local dictation worker: capture first, transcribe after stop."""

from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path


RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/tmp/regueiro-{os.getuid()}")) / "regueiro-dictation"
DATA = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "regueiro-dictation"
ENGINE = DATA / "whisper.cpp" / "build" / "bin" / "whisper-cli"
SETTINGS = DATA / "settings.json"


def selected_model() -> str:
    override = os.environ.get("REGUEIRO_DICTATION_MODEL")
    if override:
        return override
    try:
        configured = json.loads(SETTINGS.read_text(encoding="utf-8"))
        if configured.get("model") in {"small", "large-v3-turbo"}:
            return configured["model"]
    except (OSError, json.JSONDecodeError):
        pass
    # Compatible fallback for installations created before settings.json.
    return "large-v3-turbo" if (DATA / "models/ggml-large-v3-turbo.bin").is_file() else "small"


MODEL_NAME = selected_model()
MODEL = DATA / "models" / f"ggml-{MODEL_NAME}.bin"
STATE = RUNTIME / "state.json"
PID = RUNTIME / "worker.pid"
RECORDING = RUNTIME / "recording.wav"
stopping = False
recording: subprocess.Popen[str] | None = None
transcriber: subprocess.Popen[str] | None = None
cancel_transcription = False


def write_state(state: str, text: str = "", detail: str = "") -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps({"state": state, "text": text, "detail": detail}), encoding="utf-8")
    temporary.replace(STATE)


def stop_requested(_signum: int, _frame: object) -> None:
    global stopping, cancel_transcription
    stopping = True
    if recording and recording.poll() is None:
        recording.send_signal(signal.SIGINT)
    elif transcriber and transcriber.poll() is None:
        # A second toggle while Whisper is running means cancel, not "wait for
        # the model forever". Forward the signal to the child so wait() can
        # complete and the worker can clear its transcribing state.
        cancel_transcription = True
        transcriber.send_signal(signal.SIGINT)


def deliver(text: str) -> str:
    """Copy first, then best-effort paste into the still-focused app."""
    copied = False
    if shutil.which("wl-copy"):
        try:
            # Do not let wl-copy infer the MIME type from spoken text.  For
            # example, a sentence beginning with "From " is valid plain text
            # but MIME sniffing classifies it as application/mbox.
            subprocess.run(["wl-copy", "--type", "text/plain;charset=utf-8"], input=text, text=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True,
                           timeout=2)
            copied = True
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass

    typed = False
    if shutil.which("wtype"):
        try:
            # Inject a single paste shortcut, rather than hundreds of virtual
            # key events. This is substantially more reliable in Electron,
            # terminals, and browser text fields.
            subprocess.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           check=True, timeout=5)
            typed = True
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass

    if copied and typed:
        return "Copied and pasted"
    if copied:
        return "Copied to clipboard"
    if typed:
        return "Typed"
    return "Finished"


def run() -> int:
    global recording, transcriber
    if not ENGINE.is_file() or not MODEL.is_file():
        write_state("error", "", "Dictation is not installed. Run ./dictation/install.sh from the dotfiles repository.")
        return 1

    RUNTIME.mkdir(parents=True, exist_ok=True)
    PID.write_text(str(os.getpid()), encoding="utf-8")
    signal.signal(signal.SIGINT, stop_requested)
    signal.signal(signal.SIGTERM, stop_requested)

    RECORDING.unlink(missing_ok=True)
    # PipeWire writes a standard WAV file. This avoids whisper-stream's fragile
    # real-time VAD path while keeping capture entirely local.
    recording = subprocess.Popen(
        ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", str(RECORDING)],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True,
    )
    write_state("listening", "", "Listening")
    while not stopping and recording.poll() is None:
        signal.pause()

    if recording.poll() is None:
        recording.send_signal(signal.SIGINT)
    try:
        recording.wait(timeout=3)
    except subprocess.TimeoutExpired:
        recording.kill()
        recording.wait()

    if not RECORDING.is_file() or RECORDING.stat().st_size < 4096:
        write_state("ready", "", "No audio was captured")
        PID.unlink(missing_ok=True)
        return 0

    write_state("transcribing", "", "Transcribing")
    threads = str(min(os.cpu_count() or 4, 8))
    transcriber = subprocess.Popen(
        [str(ENGINE), "-m", str(MODEL), "-l", "auto", "-t", threads, "-nt", "-sns", "-f", str(RECORDING)],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    )
    output, _ = transcriber.communicate()
    transcriber = None
    if cancel_transcription:
        write_state("ready", "", "Transcription cancelled")
        PID.unlink(missing_ok=True)
        return 0

    result = " ".join(line.strip() for line in output.splitlines() if line.strip())
    # Whisper occasionally invents ambient captions such as "[Clock ticking]".
    # They are never useful as dictation, so keep only the spoken text.
    result = re.sub(r"\[[^\]]+\]", "", result).strip()
    PID.unlink(missing_ok=True)
    detail = deliver(result) if result else "No speech recognized"
    write_state("ready", result, detail)
    return 0


if __name__ == "__main__":
    sys.exit(run())
