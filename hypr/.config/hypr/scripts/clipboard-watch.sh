#!/bin/sh

set -eu

state="${CLIPBOARD_STATE:-data}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
marker="${runtime_dir}/cliphist-persist.sha256"
tmp="$(mktemp "${runtime_dir}/cliphist-watch.XXXXXX")"

cleanup() {
    rm -f "$tmp"
}
trap cleanup EXIT HUP INT TERM

if [ "$state" != "data" ]; then
    rm -f "$marker"
    exit 0
fi

cat >"$tmp"

hash="$(/sbin/sha256 -q "$tmp")"
if [ -f "$marker" ] && [ "$(cat "$marker" 2>/dev/null || true)" = "$hash" ]; then
    rm -f "$marker"
    exit 0
fi

/usr/local/bin/cliphist store <"$tmp"
printf '%s' "$hash" >"$marker"
/usr/local/bin/wl-copy <"$tmp"
