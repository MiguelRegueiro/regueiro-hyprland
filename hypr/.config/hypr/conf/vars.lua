local scripts = "~/.config/hypr/scripts"
local menu = scripts .. "/launcher-toggle.sh"

return {
    main_mod = "SUPER",
    terminal = "kitty",
    file_manager = "nautilus --new-window",
    menu = menu,
    run_menu = menu,
    clipboard_menu = "qs ipc call clipboard toggle",
    power_menu = scripts .. "/power-menu",
    snap = scripts .. "/gnome-snap",
    scripts = scripts,
}
