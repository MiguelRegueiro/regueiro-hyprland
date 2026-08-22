-- Session autostart.

hl.on("hyprland.start", function()
    -- Propagate Wayland state so systemd and D-Bus services can see it.
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")

    -- Portal stack for Flatpak, file choosers, and screenshots.
    hl.exec_cmd("sh -c 'sleep 2; killall -q xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal-termfilechooser; /usr/lib/xdg-desktop-portal-hyprland & /usr/lib/xdg-desktop-portal-gtk & /usr/lib/xdg-desktop-portal-termfilechooser & sleep 1; /usr/lib/xdg-desktop-portal &'")

    hl.exec_cmd("wl-clip-persist --clipboard regular --ignore-event-on-error")
    hl.exec_cmd("systemctl --user start mimeclipd")
    hl.exec_cmd("qs -n -d")
    hl.exec_cmd("~/.config/hypr/scripts/startup-monitor-focus.sh")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("sh -c 'until fcitx5-remote --check 2>/dev/null; do sleep 0.2; done; fcitx5-remote -s keyboard-es'")
    hl.exec_cmd("sh -c 'sleep 2 && blueman-applet'")
end)
