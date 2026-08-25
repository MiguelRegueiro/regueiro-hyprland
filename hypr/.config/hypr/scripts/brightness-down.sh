#!/bin/sh

current=$(/usr/bin/backlight -q 2>/dev/null) || exit 1

if [ "$current" -le 10 ]; then
    exec /usr/bin/backlight 5 >/dev/null
fi

exec /usr/bin/backlight decr 5 >/dev/null
