#!/usr/bin/env bash

set -euo pipefail

preferred_external="DP-1"
settle_delay="0.8"

monitor_json() {
    hyprctl monitors -j 2>/dev/null || true
}

monitor_exists() {
    local name="$1"
    jq -e --arg name "$name" '.[] | select(.name == $name)' >/dev/null <<<"$(monitor_json)"
}

monitor_center() {
    local name="$1"
    jq -r --arg name "$name" '
        .[] | select(.name == $name) | "\(.x + (.width / 2 | floor)) \(.y + (.height / 2 | floor))"
    ' <<<"$(monitor_json)" | head -n 1
}

wait_for_monitors() {
    local attempts=25

    while (( attempts > 0 )); do
        if [[ "$(monitor_json)" == \[*\] ]] && jq -e 'length > 0' >/dev/null <<<"$(monitor_json)"; then
            return 0
        fi

        sleep 0.2
        ((attempts--))
    done

    return 1
}

wait_for_monitors || exit 0
sleep "$settle_delay"

monitor_exists "$preferred_external" || exit 0

hyprctl dispatch focusmonitor "$preferred_external" >/dev/null

cursor_pos="$(monitor_center "$preferred_external")"

if [[ -n "$cursor_pos" ]]; then
    hyprctl dispatch movecursor "$cursor_pos" >/dev/null
fi
