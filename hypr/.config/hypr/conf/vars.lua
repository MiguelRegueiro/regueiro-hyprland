-- Programs and commands shared by the keybindings.

return {
    main_mod = "SUPER",
    terminal = "kitty",
    file_manager = "nautilus --new-window",
    menu = "~/.config/hypr/scripts/launcher-toggle.sh",
    run_menu = "rofi -show run",
    clipboard_menu = "qs ipc call clipboard toggle",
    power_menu = "~/.config/hypr/scripts/power-menu",
    snap = "~/.config/hypr/scripts/gnome-snap",
}
