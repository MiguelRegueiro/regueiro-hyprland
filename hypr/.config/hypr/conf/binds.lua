return function(programs)
    local main_mod = programs.main_mod
    local scripts = programs.scripts

    -- Overview and app search bindings.
    hl.bind(main_mod .. " + Super_L", hl.dsp.exec_cmd(programs.menu), { release = true })
    hl.bind(main_mod .. " + Super_R", hl.dsp.exec_cmd(programs.menu), { release = true })
    hl.bind(main_mod .. " + A", hl.dsp.exec_cmd(programs.menu))
    hl.bind("ALT + F2", hl.dsp.exec_cmd(programs.run_menu))

    -- App launcher and custom command bindings.
    hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd(programs.terminal))
    hl.bind(main_mod .. " + SHIFT + Return", hl.dsp.exec_cmd(programs.terminal .. " -e fish -ic 'runin; exec fish'"))
    hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(programs.file_manager))
    hl.bind(main_mod .. " + B", hl.dsp.exec_cmd("flatpak run app.zen_browser.zen"))
    hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(programs.terminal .. " -e btop"))
    hl.bind(main_mod .. " + D", hl.dsp.exec_cmd(programs.terminal .. " -e fish -ic 'elio; exec fish'"))
    hl.bind(main_mod .. " + W", hl.dsp.exec_cmd(programs.terminal .. " -e anitrack"))
    hl.bind(main_mod .. " + F9", hl.dsp.exec_cmd("normcap"))

    -- Window management bindings.
    hl.bind(main_mod .. " + Q", hl.dsp.window.close())
    hl.bind("ALT + F4", hl.dsp.window.close())
    hl.bind(main_mod .. " + H", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
    hl.bind(main_mod .. " + SHIFT + H", hl.dsp.workspace.toggle_special("minimized"))
    hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
    hl.bind(main_mod .. " + Up", hl.dsp.focus({ direction = "up" }))
    hl.bind(main_mod .. " + Down", hl.dsp.focus({ direction = "down" }))
    hl.bind("ALT + F5", hl.dsp.exec_cmd(programs.snap .. " restore"))
    hl.bind(main_mod .. " + Left", hl.dsp.focus({ direction = "left" }))
    hl.bind(main_mod .. " + Right", hl.dsp.focus({ direction = "right" }))
    hl.bind(main_mod .. " + CTRL + F", hl.dsp.window.float({ action = "toggle" }))

    -- Alt-Tab style focus cycling.
    hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
    hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())
    hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
    hl.bind("ALT + SHIFT + Tab", hl.dsp.window.bring_to_top())
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

    -- Workspace navigation and move bindings.
    for workspace = 1, 10 do
        local key = workspace % 10
        hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
        hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
    end

    local workspace_binds = {
        { "Page_Up", "m-1", "e-1" },
        { "Page_Down", "m+1", "e+1" },
        { "KP_Prior", "m-1", "e-1" },
        { "KP_Next", "m+1", "e+1" },
    }
    for _, binding in ipairs(workspace_binds) do
        hl.bind(main_mod .. " + " .. binding[1], hl.dsp.focus({ workspace = binding[2] }))
        hl.bind(main_mod .. " + SHIFT + " .. binding[1], hl.dsp.window.move({ workspace = binding[3] }))
    end

    for _, direction in ipairs({ "Left", "Right" }) do
        local workspace = direction == "Left" and "m-1" or "m+1"
        local move_workspace = direction == "Left" and "e-1" or "e+1"
        hl.bind(main_mod .. " + ALT + " .. direction, hl.dsp.focus({ workspace = workspace }))
        hl.bind(main_mod .. " + SHIFT + ALT + " .. direction, hl.dsp.window.move({ workspace = move_workspace }))
    end

    for _, direction in ipairs({ "Left", "Right", "Up", "Down" }) do
        local workspace = (direction == "Left" or direction == "Up") and "m-1" or "m+1"
        local move_workspace = (direction == "Left" or direction == "Up") and "e-1" or "e+1"
        hl.bind("CTRL + ALT + " .. direction, hl.dsp.focus({ workspace = workspace }))
        hl.bind("CTRL + SHIFT + ALT + " .. direction, hl.dsp.window.move({ workspace = move_workspace }))
    end

    hl.bind(main_mod .. " + Home", hl.dsp.focus({ workspace = 1 }))
    hl.bind(main_mod .. " + End", hl.dsp.focus({ workspace = 5 }))
    hl.bind(main_mod .. " + SHIFT + End", hl.dsp.window.move({ workspace = "previous" }))

    -- Resize windows.
    hl.bind(main_mod .. " + CTRL + Left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
    hl.bind(main_mod .. " + CTRL + Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
    hl.bind(main_mod .. " + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind(main_mod .. " + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

    -- Directional focus and window movement bindings.
    hl.bind(main_mod .. " + SHIFT + Left", hl.dsp.window.move({ monitor = "l" }))
    hl.bind(main_mod .. " + SHIFT + Right", hl.dsp.window.move({ monitor = "r" }))
    hl.bind(main_mod .. " + SHIFT + Up", hl.dsp.focus({ direction = "up" }))
    hl.bind(main_mod .. " + SHIFT + Down", hl.dsp.focus({ direction = "down" }))
    hl.bind(main_mod .. " + CTRL + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
    hl.bind(main_mod .. " + CTRL + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
    hl.bind(main_mod .. " + CTRL + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
    hl.bind(main_mod .. " + CTRL + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

    -- Clipboard, system, screenshots, and utilities.
    hl.bind(main_mod .. " + V", hl.dsp.exec_cmd(programs.clipboard_menu))
    hl.bind(main_mod .. " + CTRL + S", hl.dsp.exec_cmd("qs ipc call quicksettings toggle"))
    hl.bind(main_mod .. " + S", hl.dsp.exec_cmd(programs.power_menu))
    hl.bind(main_mod .. " + L", hl.dsp.exec_cmd(programs.power_menu .. " lock"))
    hl.bind(main_mod .. " + SHIFT + L", hl.dsp.exec_cmd(programs.power_menu .. " shutdown"))
    hl.bind(main_mod .. " + SHIFT + P", hl.dsp.exec_cmd(programs.power_menu .. " reboot"))
    hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(programs.power_menu .. " logout"))

    for _, key in ipairs({ "F9", "code:107" }) do
        hl.bind(key, hl.dsp.exec_cmd(scripts .. "/screenshot.sh full"))
        hl.bind("SHIFT + " .. key, hl.dsp.exec_cmd(scripts .. "/screenshot.sh freeze-area"))
        hl.bind("ALT + " .. key, hl.dsp.exec_cmd(scripts .. "/screenshot.sh window 0.15"))
    end
    hl.bind(main_mod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
    hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen())

    -- Hardware media keys.
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/vol-up.sh"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/vol-down.sh"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("/usr/sbin/mixer -f /dev/mixer0 vol.mute=toggle"), { locked = true, repeating = true })
    hl.bind(main_mod .. " + F6", hl.dsp.exec_cmd(scripts .. "/vol-up.sh"))
    hl.bind(main_mod .. " + F5", hl.dsp.exec_cmd(scripts .. "/vol-down.sh"))
    hl.bind(main_mod .. " + F7", hl.dsp.exec_cmd("/usr/sbin/mixer -f /dev/mixer0 vol.mute=toggle"))
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "/brightness-up.sh"), { repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightness-down.sh"), { repeating = true })
    hl.bind("CTRL + Up", hl.dsp.exec_cmd(scripts .. "/brightness-up.sh"), { repeating = true })
    hl.bind("CTRL + Down", hl.dsp.exec_cmd(scripts .. "/brightness-down.sh"), { repeating = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

    -- Mouse window management.
    hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
    hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "m+1" }))
    hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "m-1" }))
end
