-- Session autostart.

hl.on("hyprland.start", function()
    -- Restore this machine's saved Extend/Duplicate mode after connector
    -- discovery. The state file is deliberately outside the Stow package.
    hl.exec_cmd("sh -c 'sleep 1 && exec ~/.config/hypr/scripts/displayctl restore'")
    -- Start the shell before the login-time portal, GPU, and Python work.  QS
    -- eagerly creates every panel, so prioritising it here keeps the bar and
    -- all menus warm without pushing that work to their first use.
    -- QuickShell stays in the foreground so the session runner can stop it
    -- when this Hyprland instance exits. The launcher includes user icon paths.
    hl.exec_cmd("sh -c 'exec ~/.config/hypr/scripts/start-session-quickshell'")

    -- Let QuickShell claim the newly-created Wayland session first.  These
    -- helpers are independent of the bar and can safely start just after it.
    -- This is deliberately a delay for the helpers, never for QuickShell.
    -- Claim browser "show in folder" requests before another file manager can.
    hl.exec_cmd("sh -c 'sleep 2; app=\"$HOME/.local/bin/elio-filemanager1\"; [ -x \"$app\" ] && exec ~/.config/hypr/scripts/run-session-command --current \"$app\"'")

    -- Import the session environment before restarting portal services.
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/start-portals.sh'")

    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/start-session-services'")
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/powerctl daemon'")
    hl.exec_cmd("sh -c 'sleep 2 && exec ~/.config/hypr/scripts/set-wallpaper restore'")
    hl.exec_cmd("sh -c 'sleep 2; service=\"$HOME/.local/bin/triton-linux-service\"; [ -x \"$service\" ] && exec \"$service\" user start hyprpolkitagent.service'")
    hl.exec_cmd("sh -c 'sleep 2; command -v fcitx5 >/dev/null 2>&1 && command -v fcitx5-remote >/dev/null 2>&1 && exec ~/.config/hypr/scripts/fcitx-session.sh'")
    -- A few SOF/SoundWire sessions expose only PipeWire's auto_null fallback
    -- during login. Retry WirePlumber only if that fallback remains default.
    hl.exec_cmd("sh -c 'exec ~/.config/hypr/scripts/ensure-audio-sink'")
    -- The session helper adopts or starts the optional tray app and gracefully
    -- shuts down its host service when this Hyprland session exits.
    hl.exec_cmd("sh -c 'sleep 2; app=\"$HOME/.local/bin/triton-connect-session\"; [ -x \"$app\" ] && exec ~/.config/hypr/scripts/run-session-command --current \"$app\"'")
end)
