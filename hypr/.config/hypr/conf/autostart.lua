-- Session autostart.

hl.on("hyprland.start", function()
    -- Claim browser "show in folder" requests before another file manager can.
    hl.exec_cmd("~/.local/bin/elio-filemanager1")

    -- Import the session environment before restarting portal services.
    hl.exec_cmd("~/.config/hypr/scripts/start-portals.sh")

    hl.exec_cmd("wl-clip-persist --clipboard regular --ignore-event-on-error")
    hl.exec_cmd("systemctl --user start mimeclipd")
    hl.exec_cmd("~/.config/hypr/scripts/start-easytts.sh")
    hl.exec_cmd("qs -n -d")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("~/.config/hypr/scripts/fcitx-session.sh")
    hl.exec_cmd("sh -c 'sleep 2 && blueman-applet'")
end)
