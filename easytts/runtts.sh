#!/usr/bin/env bash

set -e

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

PYTHON="${PYTHON:-python3}"

if [[ ! -x ".venv/bin/python" ]]; then
    echo "EasyTTS: setting up local environment..."
    "$PYTHON" -m venv .venv

    .venv/bin/python -m pip install \
        --disable-pip-version-check \
        --quiet \
        -r requirements.txt

    echo "EasyTTS: ready."
fi

HOST="${EASYTTS_HOST:-}"
PORT="${EASYTTS_PORT:-8765}"

if [[ -z "$HOST" ]] && command -v tailscale >/dev/null 2>&1; then
    HOST="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
fi

URL="http://${HOST:-127.0.0.1}:${PORT}"

(
    sleep 0.7

    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$URL" >/dev/null 2>&1
    elif command -v gio >/dev/null 2>&1; then
        gio open "$URL" >/dev/null 2>&1
    fi
) &

exec .venv/bin/python app.py
