-- Personal Hyprland desktop config.

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "nautilus --new-window"
local menu = "~/.config/hypr/scripts/launcher-toggle.sh"
local runMenu = "rofi -show run"
local clipboardMenu = "qs ipc call clipboard toggle"
local powerMenu = "~/.config/hypr/scripts/power-menu"
local snap = "~/.config/hypr/scripts/gnome-snap"

hl.monitor({ output = "DP-1", mode = "1920x1080@170", position = "1600x0", scale = "1" })
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x120", scale = "1.8" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "fcitx")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_workspaces = 24,
        gaps_in = 2,
        gaps_out = 24,
        border_size = 2,
        col = {
            active_border = "rgba(818a9cff)",
            inactive_border = "rgba(393c44dd)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 16,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "rgba(00000055)",
        },
        blur = {
            enabled = true,
            size = 10,
            passes = 3,
            new_optimizations = true,
            xray = false,
            noise = 0.03,
            contrast = 1.05,
            brightness = 0.9,
            vibrancy = 0.18,
            vibrancy_darkness = 0.25,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
        key_press_enables_dpms = false,
        mouse_move_enables_dpms = true,
        vrr = 0,
    },
    render = {
        direct_scanout = false,
    },
    opengl = {
        nvidia_anti_flicker = true,
    },
    cursor = {
        no_hardware_cursors = true,
    },
    input = {
        kb_layout = "es",
        kb_options = "lv3:switch",
        follow_mouse = 1,
        sensitivity = 0,
        accel_profile = "flat",
        repeat_rate = 25,
        repeat_delay = 500,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            scroll_factor = 0.3,
        },
    },
    gestures = {
        workspace_swipe_distance = 280,
        workspace_swipe_cancel_ratio = 0.3,
        workspace_swipe_min_speed_to_force = 30,
    },
})

hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("emphasizedDecel", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("standard", { type = "bezier", points = { { 0.2, 0 }, { 0, 1 } } })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 1, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "emphasizedAccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 0.5, bezier = "standard" })
hl.animation({ leaf = "border", enabled = true, speed = 1.5, bezier = "standard" })
hl.animation({ leaf = "fade", enabled = true, speed = 1, bezier = "standard" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.3, bezier = "standard", style = "slide" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.3, bezier = "emphasizedDecel" })

hl.device({
    name = "razer-razer-viper-ultimate",
    sensitivity = 0,
    accel_profile = "flat",
})

hl.device({
    name = "syna32ee:00-06cb:cfc5-touchpad",
    sensitivity = 0,
    accel_profile = "custom 1.0 0.0 1.28",
    natural_scroll = true,
    tap_to_click = true,
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.workspace_rule({ workspace = "f[1]", gaps_out = 14, gaps_in = 4 })
hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "eDP-1", persistent = true, default = true })

hl.layer_rule({
    name = "quickshell-blur",
    match = { namespace = "quickshell" },
    blur = true,
})

hl.layer_rule({
    name = "rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
})

hl.layer_rule({
    name = "qs-border-noblur",
    match = { namespace = "qs-border" },
    blur = false,
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "elio-file-chooser",
    match = { class = "^(file_chooser)$" },
    float = true,
    center = true,
    size = { 1000, 650 },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
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

hl.bind(mainMod .. " + Super_L", hl.dsp.exec_cmd(menu), { release = true })
hl.bind(mainMod .. " + Super_R", hl.dsp.exec_cmd(menu), { release = true })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind("ALT + F2", hl.dsp.exec_cmd(runMenu))

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'runin; exec fish'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("flatpak run app.zen_browser.zen"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(terminal .. " -e btop"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'elio; exec fish'"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'env ANI_CLI_PLAYER=enzo-mpv ANI_CLI_NO_DETACH=1 anitrack; exec fish'"))
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd("normcap"))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + H", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + F5", hl.dsp.exec_cmd(snap .. " restore"))
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))

hl.bind("ALT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind("ALT + SHIFT + Tab", function()
    hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind("ALT + Escape", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Escape", hl.dsp.window.cycle_next({ next = false }))

hl.bind("ALT + F7", hl.dsp.submap("move"))
hl.define_submap("move", function()
    hl.bind("Left", hl.dsp.window.move({ x = -40, y = 0, relative = true }))
    hl.bind("Right", hl.dsp.window.move({ x = 40, y = 0, relative = true }))
    hl.bind("Up", hl.dsp.window.move({ x = 0, y = -40, relative = true }))
    hl.bind("Down", hl.dsp.window.move({ x = 0, y = 40, relative = true }))
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

hl.bind("ALT + F8", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("Left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
    hl.bind("Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
    hl.bind("Up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
    hl.bind("Down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + KP_Prior", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + KP_Next", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + ALT + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + ALT + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + ALT + Up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + Down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + Home", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + End", hl.dsp.focus({ workspace = 5 }))

hl.bind(mainMod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(mainMod .. " + SHIFT + KP_Prior", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + KP_Next", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(mainMod .. " + SHIFT + ALT + Left", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(mainMod .. " + SHIFT + ALT + Right", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Left", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Right", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Up", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Down", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(mainMod .. " + SHIFT + End", hl.dsp.window.move({ workspace = "previous", follow = true }))

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ monitor = "left", follow = true }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ monitor = "right", follow = true }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + CTRL + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipboardMenu))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("qs ipc call quicksettings toggle"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(powerMenu))

hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(powerMenu .. " lock"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(powerMenu .. " shutdown"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(powerMenu .. " reboot"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(powerMenu .. " logout"))

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("~/.config/hypr/scripts/input-toggle.sh"))
hl.bind("F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh freeze-area"))
hl.bind("ALT + F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window 0.15"))
hl.bind("code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh freeze-area"))
hl.bind("ALT + code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window 0.15"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/vol-up.sh"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/vol-down.sh"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness-up.sh"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/brightness-down.sh"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
