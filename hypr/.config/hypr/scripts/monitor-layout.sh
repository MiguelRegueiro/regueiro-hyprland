#!/usr/bin/env bash

set -euo pipefail

external="DP-1"
laptop="eDP-1"

external_rule="DP-1,1920x1080@170,1728x0,1"
laptop_external_rule="eDP-1,2880x1800@120,0x120,1.666667"
laptop_only_rule="eDP-1,2880x1800@120,0x0,1.8"

monitor_json() {
    hyprctl monitors -j 2>/dev/null || true
}

monitor_exists() {
    local name="$1"
    jq -e --arg name "$name" '.[] | select(.name == $name)' >/dev/null <<<"$(monitor_json)"
}

if monitor_exists "$external"; then
    hyprctl keyword monitor "$external_rule" >/dev/null
    hyprctl keyword monitor "$laptop_external_rule" >/dev/null
else
    hyprctl keyword monitor "$laptop_only_rule" >/dev/null
fi
