#!/usr/bin/env python3

import asyncio
import json
import os
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import edge_tts


ROOT = Path(__file__).resolve().parent


def server_address():
    """Return the interface and port on which EasyTTS should listen.

    By default, use the Tailscale IPv4 address.  This makes the app reachable
    from tailnet devices without exposing it on the machine's normal network
    interfaces.  EASYTTS_HOST and EASYTTS_PORT are available for custom setups.
    """
    host = os.environ.get("EASYTTS_HOST")
    port = int(os.environ.get("EASYTTS_PORT", "8765"))

    if host:
        return host, port

    try:
        result = subprocess.run(
            ["tailscale", "ip", "-4"],
            check=True,
            capture_output=True,
            text=True,
        )
        host = result.stdout.strip().splitlines()[0]
    except (FileNotFoundError, IndexError, subprocess.CalledProcessError):
        host = "127.0.0.1"
        print("  Tailscale IPv4 not found; listening locally only.")
        print("  Start Tailscale, then restart EasyTTS to share it on your tailnet.")

    return host, port


async def synthesize(text, voice, rate):
    started = time.perf_counter()

    communicate = edge_tts.Communicate(
        text,
        voice,
        rate=rate,
    )

    audio = bytearray()

    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            audio.extend(chunk["data"])

    elapsed = time.perf_counter() - started

    print(
        f"  {len(text):4d} chars"
        f"  → {len(audio) / 1024:6.0f} KiB"
        f"  → {elapsed:5.2f}s"
    )

    return bytes(audio)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def send_bytes(self, data, content_type, status=200):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

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

        if self.path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return

        self.send_error(404)

    def do_POST(self):
        if self.path != "/api/tts":
            self.send_error(404)
            return

        try:
            length = int(
                self.headers.get("Content-Length", 0)
            )

            payload = json.loads(
                self.rfile.read(length)
            )

            text = payload.get("text", "").strip()

            voice = payload.get(
                "voice",
                "en-US-AndrewMultilingualNeural",
            )

            rate = payload.get(
                "rate",
                "+0%",
            )

            if not text:
                self.send_json(
                    {"error": "Empty text"},
                    400,
                )
                return

            audio = asyncio.run(
                synthesize(
                    text,
                    voice,
                    rate,
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
    host, port = server_address()

    print()
    print("  EasyTTS")
    print(f"  http://{host}:{port}")
    print()
    print("  Parallel chunk mode")
    print("  Ctrl+C to stop")
    print()

    ThreadingHTTPServer(
        (host, port),
        Handler,
    ).serve_forever()
