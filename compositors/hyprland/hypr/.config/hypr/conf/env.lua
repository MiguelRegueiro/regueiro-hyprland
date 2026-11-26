-- Session environment.

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
-- Input-method variables are enabled only when the installer selection includes
-- Fcitx. GTK remains native Wayland unless a user config opts in explicitly.
local state_root = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
local selected_file = io.open(state_root .. "/triton-desktop/package-groups", "r")
local selected_groups = selected_file and selected_file:read("*a") or ""
if selected_file then selected_file:close() end
local fcitx_selected = selected_groups:match("^%s*all%s*$") ~= nil
for group in selected_groups:gmatch("[^,]+") do
    if group:match("^%s*input%s*$") then fcitx_selected = true end
end
if fcitx_selected then
    hl.env("SDL_IM_MODULE", "fcitx")
    hl.env("GLFW_IM_MODULE", "fcitx")
    hl.env("QT_IM_MODULE", "fcitx")
    hl.env("XMODIFIERS", "@im=fcitx")
end
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
