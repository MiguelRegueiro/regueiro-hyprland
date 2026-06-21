#!/bin/sh

lockdir="${TMPDIR:-/tmp}/regueiro-volume-step.lock"
if ! mkdir "$lockdir" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$lockdir"' EXIT HUP INT TERM

next=$(/usr/sbin/mixer -f /dev/mixer0 vol 2>/dev/null | awk '
    /^vol\.volume=/ {
        split($0, parts, "=")
        split(parts[2], channels, ":")
        nextValue = int((((channels[1] + channels[2]) / 2) * 100) + 0.5) - 2
        if (nextValue < 0)
            nextValue = 0
        printf "%d\n", nextValue
        exit
    }
')

[ -n "$next" ] || exit 1
/usr/sbin/mixer -f /dev/mixer0 vol="$next%" >/dev/null
(
    /usr/local/bin/canberra-gtk-play -i audio-volume-change -d 'Volume changed' 2>/dev/null ||
        /usr/local/bin/paplay /usr/local/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null ||
        /usr/local/bin/pw-play /usr/local/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null ||
        true
) &
sleep 0.02
