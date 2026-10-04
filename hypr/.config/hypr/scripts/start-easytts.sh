#!/usr/bin/env bash

set -euo pipefail

SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
ROOT="$(cd -- "$(dirname -- "$SOURCE")/../../../.." && pwd)"
RUNNER="$ROOT/easytts/runtts.sh"

# Hyprland can reload without ending the existing server process.  The Python
# command itself uses relative paths, so identify it by its working directory.
while IFS= read -r PID; do
    if [[ "$(readlink -f -- "/proc/$PID/cwd")" == "$ROOT/easytts" ]]; then
        exit 0
    fi
done < <(pgrep -u "$(id -u)" -f '\.venv/bin/python app\.py' || true)

exec env EASYTTS_OPEN_BROWSER=0 "$RUNNER"
