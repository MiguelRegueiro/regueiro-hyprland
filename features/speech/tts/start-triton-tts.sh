#!/usr/bin/env bash

set -euo pipefail

SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
TTS_ROOT="$(cd -- "$(dirname -- "$SOURCE")" && pwd)"
RUNNER="$TTS_ROOT/runtts.sh"
restart=false
background=false
session_pid=

while (($#)); do
    case "$1" in
        --restart) restart=true ;;
        --background) background=true ;;
        --session-pid)
            shift
            if (($# == 0)); then
                echo "usage: start-triton-tts.sh [--restart] [--background] [--session-pid PID]" >&2
                exit 2
            fi
            session_pid=$1
            ;;
        *)
            echo "usage: start-triton-tts.sh [--restart] [--background] [--session-pid PID]" >&2
            exit 2
            ;;
    esac
    shift
done

if [[ -n "$session_pid" ]] && { [[ ! "$session_pid" =~ ^[0-9]+$ ]] || ! kill -0 "$session_pid" 2>/dev/null; }; then
    echo "Invalid or inactive session PID" >&2
    exit 2
fi

# Hyprland already launches commands independently. This mode exists for
# manual starts from a terminal, and uses no systemd-specific behavior.
if "$background" && [[ -z "${EASYTTS_BACKGROUND_CHILD:-}" ]]; then
    arguments=()
    "$restart" && arguments+=(--restart)
    [[ -n "$session_pid" ]] && arguments+=(--session-pid "$session_pid")
    nohup env EASYTTS_BACKGROUND_CHILD=1 "$0" "${arguments[@]}" \
        </dev/null >/tmp/triton-tts.log 2>&1 &
    echo "Triton TTS started in the background (log: /tmp/triton-tts.log)"
    exit 0
fi

# Hyprland can reload without ending the existing server process.  The Python
# command itself uses relative paths, so identify it by its working directory.
active_pids=()
while IFS= read -r PID; do
    if [[ "$(readlink -f -- "/proc/$PID/cwd")" == "$TTS_ROOT" ]]; then
        active_pids+=("$PID")
    fi
done < <(pgrep -u "$(id -u)" -f '\.venv/bin/python app\.py' || true)

if ((${#active_pids[@]})); then
    if ! "$restart"; then
        exit 0
    fi

    kill -TERM "${active_pids[@]}"
    for _ in {1..50}; do
        still_running=false
        for PID in "${active_pids[@]}"; do
            if kill -0 "$PID" 2>/dev/null; then
                still_running=true
                break
            fi
        done
        if ! "$still_running"; then
            break
        fi
        sleep 0.1
    done

    if "$still_running"; then
        echo "Triton TTS did not stop cleanly" >&2
        exit 1
    fi
fi

if [[ -n "$session_pid" ]]; then
    exec env EASYTTS_OPEN_BROWSER=0 TRITON_SESSION_PID="$session_pid" "$RUNNER"
fi
exec env EASYTTS_OPEN_BROWSER=0 "$RUNNER"
