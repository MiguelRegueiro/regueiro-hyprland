#!/usr/bin/env python3
"""Shared, short-lived Kokoro worker with CUDA-first / CPU fallback."""

from __future__ import annotations

import json
import os
import select
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
IDLE_SECONDS = 90
VOICES = {"kokoro-michael": "am_michael", "kokoro-onyx": "am_onyx"}
SPEEDS = {"0.75": 0.75, "1": 1.0, "1.25": 1.25, "1.5": 1.5, "1.75": 1.75, "2": 2.0,
          "-25%": 0.75, "+0%": 1.0, "+25%": 1.25, "+50%": 1.5, "+75%": 1.75, "+100%": 2.0}
MIN_CUDA_VRAM_MIB = 3 * 1024


def reply(**payload):
    print(json.dumps(payload), flush=True)


def use_cuda(ort):
    """Use CUDA only where Kokoro's long-text workspace is known to fit.

    A CUDA-capable MX250 has only 2 GB VRAM.  Trying it first causes an
    allocation failure instead of a useful fallback, while CPU mode remains
    reliable on the older laptop's ample system memory.
    """
    preference = os.environ.get("EASYTTS_KOKORO_DEVICE", "auto").lower()
    if preference == "cpu":
        return False
    if "CUDAExecutionProvider" not in ort.get_available_providers():
        return False
    if preference == "cuda":
        return True
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            check=True, capture_output=True, text=True,
        )
        vram_mib = max(int(line.strip()) for line in result.stdout.splitlines() if line.strip())
        return vram_mib >= MIN_CUDA_VRAM_MIB
    except (FileNotFoundError, ValueError, subprocess.CalledProcessError):
        return False


def use_openvino(ort):
    preference = os.environ.get("EASYTTS_KOKORO_DEVICE", "auto").lower()
    return preference != "cpu" and preference != "cuda" and "OpenVINOExecutionProvider" in ort.get_available_providers()


def main():
    import onnxruntime as ort
    import soundfile as sf
    from kokoro_onnx import Kokoro

    if use_cuda(ort):
        providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
    elif use_openvino(ort):
        # AUTO prefers the Intel iGPU, then falls back to the Intel CPU for
        # unsupported operations.  This is the useful path on the MX250
        # laptop: the 2 GB NVIDIA GPU cannot fit long Kokoro requests.
        providers = [("OpenVINOExecutionProvider", {"device_type": "AUTO:GPU,CPU"}), "CPUExecutionProvider"]
    else:
        providers = ["CPUExecutionProvider"]
    # Long paragraphs need multiple large decoder workspaces. The worker exits
    # five seconds after synthesis, so permit the proven ~2.2 GB active peak
    # rather than failing a reading midway through.
    cuda_options = {"gpu_mem_limit": 3 * 1024 * 1024 * 1024, "arena_extend_strategy": "kSameAsRequested"}
    session = ort.InferenceSession(
        str(ROOT / ".kokoro-model" / "kokoro-v1.0.onnx"),
        providers=[("CUDAExecutionProvider", cuda_options), "CPUExecutionProvider"] if providers[0] == "CUDAExecutionProvider" else providers,
    )
    model = Kokoro.from_session(session, str(ROOT / ".kokoro-model" / "voices-v1.0.bin"))
    reply(ready=True, provider=session.get_providers()[0])

    while select.select([sys.stdin], [], [], IDLE_SECONDS)[0]:
        line = sys.stdin.readline()
        if not line:
            break
        try:
            request = json.loads(line)
            output = Path(request["output"])
            voice = VOICES.get(request.get("voice"), "am_michael")
            speed = SPEEDS.get(str(request.get("rate", "1.5")), 1.5)
            # Kokoro's native speed parameter changes the prosody model and
            # becomes muddy above 1x.  Generate clear, natural speech first;
            # then apply a transparent time stretch plus loudness normalization.
            samples, sample_rate = model.create(request["text"], voice=voice, speed=1.0, lang="en-us")
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temporary:
                wav_path = Path(temporary.name)
            try:
                sf.write(wav_path, samples, sample_rate)
                subprocess.run(
                    ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-filter:a",
                     f"loudnorm=I=-16:TP=-1.5:LRA=11,atempo={speed}",
                     "-codec:a", "libmp3lame", "-q:a", "2", str(output)],
                    check=True,
                )
            finally:
                wav_path.unlink(missing_ok=True)
            reply(ok=True)
        except Exception as error:
            reply(ok=False, error=str(error))


if __name__ == "__main__":
    main()
