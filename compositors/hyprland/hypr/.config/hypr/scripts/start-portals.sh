#!/usr/bin/env bash
set -euo pipefail
[[ ":${XDG_CURRENT_DESKTOP:-}:" == *:Hyprland:* ]] || exit 0
service_manager="${HOME}/.local/bin/triton-linux-service"
if [[ ! -x "$service_manager" ]]; then
    echo "Skipping Linux portal activation: the Linux service adapter is unavailable." >&2
    exit 0
fi
# Do not import IM variables into the user-wide activation environment.
"$service_manager" activation-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE

# Plain GDM Hyprland sessions may not activate graphical-session.target.
# Start a monitor that stops the session-owned services when this compositor
# exits. UWSM-managed targets already provide that lifecycle.
uwsm_units=$("$service_manager" user list-units --type=service \
    --state=active,activating --plain --no-legend --no-pager \
    'wayland-wm@*.service' 2>/dev/null) || uwsm_units=""
if [[ -z "$uwsm_units" ]]; then
    compositor_pid=""
    for ((attempt = 0; attempt < 50; attempt++)); do
        compositor_pid=$(hyprctl instances -j 2>/dev/null | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE" \
            '.[] | select(.instance == $instance) | .pid' 2>/dev/null) || compositor_pid=""
        [[ "$compositor_pid" =~ ^[0-9]+$ ]] && kill -0 "$compositor_pid" 2>/dev/null && break
        sleep 0.2
    done
    [[ "$compositor_pid" =~ ^[0-9]+$ ]] || exit 1
    "$service_manager" run-user --collect --unit="regueiro-hyprland-session-${compositor_pid}" \
        "$HOME/.local/bin/triton-linux-session-cleanup" "$compositor_pid"
fi

# Service files know the right binary locations on both Fedora and Arch.
"$service_manager" user stop xdg-desktop-portal.service
for backend in gtk hyprland; do
    "$service_manager" user restart "xdg-desktop-portal-${backend}.service" || \
        echo "${backend} portal failed; continuing to start the main portal." >&2
done
if "$service_manager" user cat xdg-desktop-portal-termfilechooser.service >/dev/null 2>&1; then
    "$service_manager" user restart xdg-desktop-portal-termfilechooser.service || \
        echo "termfilechooser failed; see README for GTK recovery." >&2
fi
"$service_manager" user start xdg-desktop-portal.service
