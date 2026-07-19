#!/bin/sh

sink_name="regueiro_output"
master_sink="oss_output.dsp0"

if ! /usr/local/bin/pactl list short sinks | awk -v sink="$sink_name" '$2 == sink { found = 1 } END { exit !found }'; then
    master_index=$(/usr/local/bin/pactl list short sinks | awk -v sink="$master_sink" '$2 == sink { print $1; exit }')
    [ -n "$master_index" ] || exit 1

    /usr/local/bin/pactl load-module module-remap-sink \
        sink_name="$sink_name" \
        master="$master_index" \
        remix=no >/dev/null || exit 1
fi

/usr/sbin/mixer -f /dev/mixer0 vol=100% >/dev/null 2>&1
/usr/local/bin/pactl set-default-sink "$sink_name"

/usr/local/bin/pactl list short sink-inputs | awk '{ print $1 }' | while read -r input_id; do
    [ -n "$input_id" ] && /usr/local/bin/pactl move-sink-input "$input_id" "$sink_name" >/dev/null 2>&1
done

exit 0
