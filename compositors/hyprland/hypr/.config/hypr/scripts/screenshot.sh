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
    local mimeclip_bin="$HOME/.cargo/bin/mimeclip"

    if [[ ! -x "$mimeclip_bin" ]]; then
        if [[ -x /usr/local/bin/mimeclip ]]; then
            mimeclip_bin=/usr/local/bin/mimeclip
        else
            mimeclip_bin="$(command -v mimeclip 2>/dev/null || true)"
        fi
    fi

    if [[ -z "$mimeclip_bin" || ! -x "$mimeclip_bin" ]]; then
        fail "mimeclip is not installed"
    fi

    "$mimeclip_bin" screenshot "$1"
}

notify_saved() {
    local action

    if command -v notify-send >/dev/null 2>&1; then
        action="$(notify-send \
            -a "Screenshot" \
            -i "image-x-generic" \
            -h "string:image-path:$1" \
            -A "default=Open" \
            "Screenshot saved" "$1" || true)"

        if [[ "$action" == "default" ]]; then
            xdg-open "$1" >/dev/null 2>&1 &
        fi
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
