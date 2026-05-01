#!/usr/bin/env bash

set -euo pipefail

mode="${1:-full}"
launch_delay="${2:-0}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
file="$dir/Screenshot_${timestamp}.png"
log_file="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-screenshot.log"

mkdir -p "$dir"
mkdir -p "$(dirname "$log_file")"

log() {
    printf '%s [%s] %s\n' "$(date +'%F %T')" "$mode" "$*" >>"$log_file"
}

fail() {
    log "error: $*"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot failed" "$*"
    fi
    exit 1
}

trap 'rc=$?; if [[ $rc -ne 0 ]]; then log "exit status $rc"; fi' EXIT

if [[ "$launch_delay" != "0" ]]; then
    sleep "$launch_delay"
fi

copy_image() {
    wl-copy --type image/png <"$1"
}

notify_saved() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Screenshot saved" "$1"
    fi
}

focused_monitor_name() {
    hyprctl monitors -j | jq -r '
        .[] | select(.focused == true) | .name
    ' | head -n 1
}

capture_full() {
    local output
    output="$(focused_monitor_name)"

    if [[ -z "$output" || "$output" == "null" ]]; then
        fail "no focused monitor detected"
    fi

    log "capturing focused output: $output"
    grim -o "$output" "$file"
}

capture_freeze_area() {
    local geometry

    for cmd in grim slurp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            fail "$cmd is not installed"
        fi
    done

    if ! geometry="$(slurp -d)"; then
        log "area selection cancelled"
        exit 0
    fi

    log "capturing area: $geometry"
    grim -g "$geometry" "$file"
}

capture_window() {
    local geometry
    geometry="$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')"

    if [[ -z "$geometry" || "$geometry" == "null,null nullxnull" ]]; then
        fail "no active window geometry available"
    fi

    log "capturing window geometry: $geometry"
    grim -g "$geometry" "$file"
}

log "start"

case "$mode" in
full)
    capture_full
    ;;
freeze-area)
    capture_freeze_area
    ;;
window)
    capture_window
    ;;
*)
    echo "Usage: $0 {full|freeze-area|window}" >&2
    exit 2
    ;;
esac

copy_image "$file"
notify_saved "$file"
log "saved $file"
printf '%s\n' "$file"
