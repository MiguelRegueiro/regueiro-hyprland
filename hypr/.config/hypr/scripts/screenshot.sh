#!/usr/bin/env bash

set -euo pipefail

mode="${1:-full}"
launch_delay="${2:-0}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
file="$dir/Screenshot_${timestamp}.png"
log_file="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-screenshot.log"
label_cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-screenshot-labels.tsv"

mkdir -p "$dir"
mkdir -p "$(dirname "$log_file")"

log() {
    printf '%s [%s] %s\n' "$(date +'%F %T')" "$mode" "$*" >>"$log_file"
}

fail() {
    log "error: $*"
    exit 1
}

trap 'rc=$?; if [[ $rc -ne 0 ]]; then log "exit status $rc"; fi' EXIT

if [[ "$launch_delay" != "0" ]]; then
    sleep "$launch_delay"
fi

copy_image() {
    wl-copy --type image/png <"$1"
}

register_clipboard_label() {
    local source_file="$1"
    local target_hash clip_label clock attempt id preview decoded_file decoded_hash tmp_labels

    target_hash="$(sha256sum "$source_file" | awk '{print $1}')" || return 1
    clock="${timestamp#*_}"
    clip_label="Screenshot ${clock//-/:}"

    for attempt in {1..20}; do
        while IFS=$'\t' read -r id preview; do
            [[ -n "$id" ]] || continue
            decoded_file="$(mktemp)"
            if printf '%s' "$id" | cliphist decode >"$decoded_file" 2>/dev/null; then
                decoded_hash="$(sha256sum "$decoded_file" | awk '{print $1}')"
                rm -f "$decoded_file"
                if [[ "$decoded_hash" == "$target_hash" ]]; then
                    mkdir -p "$(dirname "$label_cache_file")"
                    tmp_labels="$(mktemp)"
                    {
                        printf '%s\t%s\t%s\n' "$id" "$clip_label" "$source_file"
                        grep -Fv "${id}"$'\t' "$label_cache_file" 2>/dev/null || true
                    } >"$tmp_labels"
                    mv "$tmp_labels" "$label_cache_file"
                    log "registered clipboard label: $id -> $clip_label"
                    return 0
                fi
            else
                rm -f "$decoded_file"
            fi
        done < <(cliphist list | head -n 12)
        sleep 0.05
    done

    log "warning: failed to register clipboard label"
    return 1
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

capture_area() {
    local geometry
    geometry="$(slurp -d)" || exit 0
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

annotate_area() {
    local geometry
    geometry="$(slurp -d)" || exit 0
    log "annotating area: $geometry"
    grim -g "$geometry" - | swappy -f -
    exit 0
}

log "start"

case "$mode" in
full)
    capture_full
    ;;
area)
    capture_area
    ;;
window)
    capture_window
    ;;
annotate)
    annotate_area
    ;;
*)
    echo "Usage: $0 {full|area|window|annotate}" >&2
    exit 2
    ;;
esac

copy_image "$file"
register_clipboard_label "$file" || true
notify_saved "$file"
log "saved $file"
printf '%s\n' "$file"
