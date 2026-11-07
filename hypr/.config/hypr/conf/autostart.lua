-- Session autostart.

hl.on("hyprland.start", function()
    -- Start the shell before the login-time portal, GPU, and Python work.  QS
    -- eagerly creates every panel, so prioritising it here keeps the bar and
    -- all menus warm without pushing that work to their first use.
    -- Include per-user icon themes before QuickShell starts.  In particular,
    -- this lets StatusNotifier tray icons resolve from ~/.local/share on both
    -- Arch-based systems and Fedora instead of falling back to a placeholder.
    hl.exec_cmd("sh -c 'export XDG_DATA_DIRS=\"$HOME/.local/share:$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"; exec qs -n -d'")

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
    -- A few SOF/SoundWire sessions expose only PipeWire's auto_null fallback
    -- during login. Retry WirePlumber only if that fallback remains default.
    hl.exec_cmd("sh -c 'exec ~/.config/hypr/scripts/ensure-audio-sink'")
    -- Triton Connect owns its tray window and starts its paired-device daemon
    -- itself. It is optional so a fresh dotfiles install can still start a
    -- session before Triton has been bootstrapped.
    hl.exec_cmd("sh -c 'sleep 2; app=\"$HOME/.local/bin/triton-control\"; [ -x \"$app\" ] && exec \"$app\" --background'")
end)
