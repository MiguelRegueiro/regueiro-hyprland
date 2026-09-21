#!/usr/bin/env bash
# Own only the Fcitx process started here; never kill another desktop's IME.
set -euo pipefail

[[ ":${XDG_CURRENT_DESKTOP:-}:" == *:Hyprland:* ]] || exit 0
: "${HYPRLAND_INSTANCE_SIGNATURE:?A running Hyprland session is required}"
: "${XDG_RUNTIME_DIR:?A running user session is required}"

# The start hook can run before Hyprland publishes its instance metadata.
compositor_pid=""
for ((attempt = 0; attempt < 50; attempt++)); do
    compositor_pid=$(hyprctl instances -j 2>/dev/null | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE"         '.[] | select(.instance == $instance) | .pid' 2>/dev/null) || compositor_pid=""
    if [[ "$compositor_pid" =~ ^[0-9]+$ ]] && kill -0 "$compositor_pid" 2>/dev/null; then
        break
    fi
    sleep 0.2
done
[[ "$compositor_pid" =~ ^[0-9]+$ ]] || { echo "Hyprland instance was not published within 10 seconds." >&2; exit 1; }
kill -0 "$compositor_pid" 2>/dev/null || exit 1

exec 9>"$XDG_RUNTIME_DIR/fcitx-hyprland-session.lock"
flock -n 9 || exit 0

# Do not replace a Fcitx instance owned by another graphical session.
if fcitx5-remote --check >/dev/null 2>&1; then
    echo "Fcitx is already running; refusing to take over another session." >&2
    exit 1
fi

fcitx5 -D &
fcitx_pid=$!
cleanup() {
    kill "$fcitx_pid" 2>/dev/null || true
    wait "$fcitx_pid" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

# Bound startup waiting, including when the daemon cannot initialize.
ready=false
for ((attempt = 0; attempt < 50; attempt++)); do
    kill -0 "$fcitx_pid" 2>/dev/null || exit 1
    kill -0 "$compositor_pid" 2>/dev/null || exit 0
    if fcitx5-remote --check >/dev/null 2>&1; then
        fcitx5-remote -s keyboard-es
        ready=true
        break
    fi
    sleep 0.2
done

if [[ "$ready" != true ]]; then
    echo "Fcitx did not become ready within 10 seconds." >&2
    exit 1
fi

# Also handle compositor crashes, not just a normal logout hook.
while kill -0 "$compositor_pid" 2>/dev/null && kill -0 "$fcitx_pid" 2>/dev/null; do
    sleep 1
done
