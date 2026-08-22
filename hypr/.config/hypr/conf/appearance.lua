-- Look and feel.

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
