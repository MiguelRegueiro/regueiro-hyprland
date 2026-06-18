#!/bin/sh

set -eu

settings_dir="${XDG_CONFIG_HOME:-$HOME/.config}/discord"
settings_file="$settings_dir/settings.json"
settings_json='{"SKIP_HOST_UPDATE": true}'

if ! command -v doas >/dev/null 2>&1; then
    printf 'doas is required to set FreeBSD schg flags on %s\n' "$settings_file" >&2
    exit 1
fi

mkdir -p "$settings_dir"

if [ -e "$settings_file" ]; then
    doas chflags noschg "$settings_file" 2>/dev/null || true
fi

printf '%s\n' "$settings_json" > "$settings_file"
doas chflags schg "$settings_file"

printf 'Discord runtime override installed: %s\n' "$settings_file"
