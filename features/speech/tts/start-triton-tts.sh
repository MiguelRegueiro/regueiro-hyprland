#!/usr/bin/env bash

set -euo pipefail

SOURCE="$(realpath "${BASH_SOURCE[0]}")"
TTS_ROOT="$(cd -- "$(dirname -- "$SOURCE")" && pwd)"
RUNNER="$TTS_ROOT/runtts.sh"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    RUNTIME_DIR="$XDG_RUNTIME_DIR/triton-tts"
else
    RUNTIME_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/triton-tts/runtime"
fi
PID_FILE="$RUNTIME_DIR/server.pid"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/triton-tts/server.log"
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
if "$background" && [[ -z "${TRITON_TTS_BACKGROUND_CHILD:-${EASYTTS_BACKGROUND_CHILD:-}}" ]]; then
    arguments=()
    "$restart" && arguments+=(--restart)
    [[ -n "$session_pid" ]] && arguments+=(--session-pid "$session_pid")
    mkdir -p "$(dirname -- "$LOG_FILE")"
    nohup env TRITON_TTS_BACKGROUND_CHILD=1 "$0" "${arguments[@]}" \
        </dev/null >"$LOG_FILE" 2>&1 &
    echo "Triton TTS started in the background (log: $LOG_FILE)"
    exit 0
fi

server_pid_is_active() {
    local candidate=$1 command
    [[ "$candidate" =~ ^[0-9]+$ ]] && kill -0 "$candidate" 2>/dev/null || return 1
    command=$(ps -ww -p "$candidate" -o command= 2>/dev/null || true)
    [[ "$command" == *".venv/bin/python app.py"* ]]
}

active_pids=()
if [[ -r "$PID_FILE" ]]; then
    PID=$(<"$PID_FILE")
    if server_pid_is_active "$PID"; then
        active_pids+=("$PID")
    else
        rm -f "$PID_FILE"
    fi
fi

if ((${#active_pids[@]})); then
    if ! "$restart"; then
        exit 0
    fi

    kill -TERM "${active_pids[@]}"
    for _ in {1..50}; do
        still_running=false
        for PID in "${active_pids[@]}"; do
            if server_pid_is_active "$PID"; then
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
    exec env TRITON_TTS_OPEN_BROWSER=0 TRITON_TTS_PID_FILE="$PID_FILE" \
        TRITON_SESSION_PID="$session_pid" "$RUNNER"
fi
exec env TRITON_TTS_OPEN_BROWSER=0 TRITON_TTS_PID_FILE="$PID_FILE" "$RUNNER"
