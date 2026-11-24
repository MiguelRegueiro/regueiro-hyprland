#!/usr/bin/env bash
set -euo pipefail
[[ ":${XDG_CURRENT_DESKTOP:-}:" == *:Hyprland:* ]] || exit 0
# Do not import IM variables into the user-wide activation environment.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE

# Plain GDM Hyprland sessions may not activate graphical-session.target.
# A transient service holds that target only while this compositor PID exists.
# UWSM/GNOME-managed targets need no additional owner.
if ! systemctl --user is-active --quiet graphical-session.target; then
    compositor_pid=""
    for ((attempt = 0; attempt < 50; attempt++)); do
        compositor_pid=$(hyprctl instances -j 2>/dev/null | jq -er --arg instance "$HYPRLAND_INSTANCE_SIGNATURE" \
            '.[] | select(.instance == $instance) | .pid' 2>/dev/null) || compositor_pid=""
        [[ "$compositor_pid" =~ ^[0-9]+$ ]] && kill -0 "$compositor_pid" 2>/dev/null && break
        sleep 0.2
    done
    [[ "$compositor_pid" =~ ^[0-9]+$ ]] || exit 1
    systemd-run --user --collect --unit="regueiro-hyprland-session-${compositor_pid}" \
        --property=BindsTo=graphical-session.target \
        --property=After=graphical-session.target \
        /bin/sh -c 'while kill -0 "$1" 2>/dev/null; do sleep 1; done' sh "$compositor_pid"
fi

# Service files know the right binary locations on both Fedora and Arch.
systemctl --user stop xdg-desktop-portal.service
for backend in gtk hyprland; do
    systemctl --user restart "xdg-desktop-portal-${backend}.service" || \
        echo "${backend} portal failed; continuing to start the main portal." >&2
done
if systemctl --user cat xdg-desktop-portal-termfilechooser.service >/dev/null 2>&1; then
    systemctl --user restart xdg-desktop-portal-termfilechooser.service || \
        echo "termfilechooser failed; see README for GTK recovery." >&2
fi
systemctl --user start xdg-desktop-portal.service
