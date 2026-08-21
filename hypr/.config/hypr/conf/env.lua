local environment = {
    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_SESSION_DESKTOP = "Hyprland",
    XDG_SESSION_TYPE = "wayland",
    GDK_BACKEND = "wayland",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_QPA_PLATFORMTHEME = "gtk3",
    MOZ_ENABLE_WAYLAND = "1",
    LIBVA_DRIVER_NAME = "iHD",
    SDL_VIDEODRIVER = "wayland,x11",
    CLUTTER_BACKEND = "wayland",
    XCURSOR_THEME = "Bibata-Modern-Classic",
    XCURSOR_SIZE = "24",
    HYPRCURSOR_THEME = "Bibata-Modern-Classic",
    HYPRCURSOR_SIZE = "24",
}

for name, value in pairs(environment) do
    hl.env(name, value)
end
