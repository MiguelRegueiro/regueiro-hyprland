local commands = {
    "dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE",
    [=[command -v xrdb >/dev/null 2>&1 && xrdb -merge "$HOME/.Xresources"]=],
    [=[exec "$HOME/.config/hypr/scripts/apply-appearance.sh"]=],
    "hyprpaper",
    [=[exec "$HOME/.config/hypr/scripts/brightness-restore.sh"]=],
    [=[sleep 2; exec "$HOME/.config/hypr/scripts/brightness-restore.sh"]=],
    "hypridle -q",
    "/usr/local/libexec/hyprpolkitagent",
    "pipewire",
    "wireplumber",
    [=[sleep 1; exec "$HOME/.config/hypr/scripts/audio-output-setup.sh"]=],
    [=[pgrep -x wl-paste >/dev/null || daemon -p "${XDG_RUNTIME_DIR:-/tmp}/cliphist-watcher.pid" -o "${XDG_RUNTIME_DIR:-/tmp}/cliphist-watcher.log" /usr/local/bin/wl-paste --watch "$HOME/.config/hypr/scripts/clipboard-watch.sh"]=],
    "qs -n -d",
}

hl.on("hyprland.start", function()
    for _, command in ipairs(commands) do
        hl.exec_cmd(command)
    end
end)
