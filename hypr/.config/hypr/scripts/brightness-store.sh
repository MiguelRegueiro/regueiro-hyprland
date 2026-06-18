#!/bin/sh

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backlight"
state_file="$state_dir/brightness"
log_file="$state_dir/brightness.log"

case "$1" in
  save)
    value="$2"
    ;;
  current)
    value=$(/usr/bin/backlight -q 2>/dev/null)
    ;;
  *)
    exit 64
    ;;
esac

case "$value" in
  ''|*[!0-9]*)
    exit 65
    ;;
esac

[ "$value" -lt 1 ] && value=1
[ "$value" -gt 100 ] && value=100

mkdir -p "$state_dir" || exit 1
printf '%s\n' "$value" > "$state_file"
printf '%s store %s\n' "$(date '+%F %T')" "$value" >> "$log_file"
