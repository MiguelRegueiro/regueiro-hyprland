#!/bin/sh

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backlight"
state_file="$state_dir/brightness"
log_file="$state_dir/brightness.log"

[ -r "$state_file" ] || exit 0

value=$(sed -n '1{s/[^0-9].*$//;p;}' "$state_file")

case "$value" in
  ''|*[!0-9]*)
    exit 0
    ;;
esac

[ "$value" -lt 1 ] && value=1
[ "$value" -gt 100 ] && value=100

before=$(/usr/bin/backlight -q 2>/dev/null)
/usr/bin/backlight "$value" || exit 1
after=$(/usr/bin/backlight -q 2>/dev/null)

mkdir -p "$state_dir" || exit 1
printf '%s restore saved=%s before=%s after=%s\n' "$(date '+%F %T')" "$value" "$before" "$after" >> "$log_file"
