-- Session autostart.

hl.on("hyprland.start", function()
    -- Start the shell before the login-time portal, GPU, and Python work.  QS
    -- eagerly creates every panel, so prioritising it here keeps the bar and
    -- all menus warm without pushing that work to their first use.
    hl.exec_cmd("qs -n -d")

    -- Let QuickShell claim the newly-created Wayland session first.  These
    -- helpers are independent of the bar and can safely start just after it.
    -- This is deliberately a delay for the helpers, never for QuickShell.
    -- Claim browser "show in folder" requests before another file manager can.
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.local/bin/elio-filemanager1'")

    -- Import the session environment before restarting portal services.
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/start-portals.sh'")

    -- Hyprland's PATH may exclude Cargo; prefer a system install, then Cargo.
    hl.exec_cmd("sh -c 'sleep 2; persist=$(command -v wl-clip-persist || true); persist=${persist:-\"$HOME/.cargo/bin/wl-clip-persist\"}; [ -x \"$persist\" ] && exec \"$persist\" --clipboard regular --ignore-event-on-error'")
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/start-mimeclip'")
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/start-easytts.sh'")
    hl.exec_cmd("sh -c 'sleep 2 && exec hypridle'")
    hl.exec_cmd("sh -c 'sleep 2 && exec hyprpaper'")
    hl.exec_cmd("sh -c 'sleep 2 && exec systemctl --user start hyprpolkitagent.service'")
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/fcitx-session.sh'")
    hl.exec_cmd("sh -c 'sleep 2 && exec blueman-applet'")
end)
