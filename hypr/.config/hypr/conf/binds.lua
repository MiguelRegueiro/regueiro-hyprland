-- Keyboard and mouse bindings.

local vars = require("conf.vars")

local main_mod = vars.main_mod
local terminal = vars.terminal
local file_manager = vars.file_manager
local menu = vars.menu
local run_menu = vars.run_menu
local clipboard_menu = vars.clipboard_menu
local power_menu = vars.power_menu
local snap = vars.snap

-- Overview, app search, and launchers.
hl.bind(main_mod .. " + Super_L", hl.dsp.exec_cmd(menu), { release = true })
hl.bind(main_mod .. " + Super_R", hl.dsp.exec_cmd(menu), { release = true })
hl.bind(main_mod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind("ALT + F2", hl.dsp.exec_cmd(run_menu))

hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + SHIFT + Return", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'runin; exec fish'"))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(main_mod .. " + B", hl.dsp.exec_cmd("flatpak run app.zen_browser.zen"))
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(terminal .. " -e btop"))
hl.bind(main_mod .. " + D", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'elio; exec fish'"))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd(terminal .. " -e fish -ic 'env ANI_CLI_PLAYER=enzo-mpv ANI_CLI_NO_DETACH=1 anitrack; exec fish'"))
hl.bind(main_mod .. " + F9", hl.dsp.exec_cmd("normcap"))

-- Window management.
hl.bind(main_mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(main_mod .. " + H", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind(main_mod .. " + SHIFT + H", hl.dsp.workspace.toggle_special("minimized"))
hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(main_mod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + F5", hl.dsp.exec_cmd(snap .. " restore"))
hl.bind(main_mod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(main_mod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(main_mod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))

-- Alt-Tab style focus cycling.
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

-- Move and resize submaps.
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

-- Workspace navigation and moving windows between workspaces.
for i = 1, 10 do
    local key = i % 10
    hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
end

hl.bind(main_mod .. " + Page_Up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(main_mod .. " + Page_Down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(main_mod .. " + KP_Prior", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(main_mod .. " + KP_Next", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(main_mod .. " + ALT + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(main_mod .. " + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + ALT + Left", hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + Right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind("CTRL + ALT + Up", hl.dsp.focus({ workspace = "m-1" }))
hl.bind("CTRL + ALT + Down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(main_mod .. " + Home", hl.dsp.focus({ workspace = 1 }))
hl.bind(main_mod .. " + End", hl.dsp.focus({ workspace = 5 }))

hl.bind(main_mod .. " + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(main_mod .. " + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(main_mod .. " + SHIFT + KP_Prior", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(main_mod .. " + SHIFT + KP_Next", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(main_mod .. " + SHIFT + ALT + Left", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind(main_mod .. " + SHIFT + ALT + Right", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Left", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Right", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Up", hl.dsp.window.move({ workspace = "e-1", follow = true }))
hl.bind("CTRL + SHIFT + ALT + Down", hl.dsp.window.move({ workspace = "e+1", follow = true }))
hl.bind(main_mod .. " + SHIFT + End", hl.dsp.window.move({ workspace = "previous", follow = true }))

-- Resize, focus, and move windows directionally.
hl.bind(main_mod .. " + CTRL + Left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + CTRL + Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(main_mod .. " + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(main_mod .. " + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

hl.bind(main_mod .. " + SHIFT + Left", hl.dsp.window.move({ monitor = "left", follow = true }))
hl.bind(main_mod .. " + SHIFT + Right", hl.dsp.window.move({ monitor = "right", follow = true }))
hl.bind(main_mod .. " + SHIFT + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + SHIFT + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(main_mod .. " + CTRL + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind(main_mod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind(main_mod .. " + CTRL + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind(main_mod .. " + CTRL + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

-- Clipboard, shell panels, power, input, screenshots, and utilities.
hl.bind(main_mod .. " + V", hl.dsp.exec_cmd(clipboard_menu))
hl.bind(main_mod .. " + CTRL + S", hl.dsp.exec_cmd("qs ipc call quicksettings toggle"))
hl.bind(main_mod .. " + S", hl.dsp.exec_cmd(power_menu))

hl.bind(main_mod .. " + L", hl.dsp.exec_cmd(power_menu .. " lock"))
hl.bind(main_mod .. " + SHIFT + L", hl.dsp.exec_cmd(power_menu .. " shutdown"))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd(power_menu .. " reboot"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(power_menu .. " logout"))

hl.bind(main_mod .. " + Space", hl.dsp.exec_cmd("~/.config/hypr/scripts/input-toggle.sh"))
hl.bind("F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh freeze-area"))
hl.bind("ALT + F9", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window 0.15"))
hl.bind("code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh freeze-area"))
hl.bind("ALT + code:107", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot.sh window 0.15"))
hl.bind(main_mod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Hardware media keys.
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

-- Mouse window management and workspace scrolling.
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
