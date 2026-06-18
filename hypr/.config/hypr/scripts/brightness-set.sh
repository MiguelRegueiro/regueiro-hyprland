#!/bin/sh

case "$1" in
  ''|*[!0-9]*)
    exit 64
    ;;
esac

value="$1"

[ "$value" -lt 1 ] && value=1
[ "$value" -gt 100 ] && value=100

/usr/bin/backlight "$value" || exit 1
"$HOME/.config/hypr/scripts/brightness-store.sh" save "$value"
