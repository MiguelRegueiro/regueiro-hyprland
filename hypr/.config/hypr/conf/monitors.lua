-- Machine-local settings live outside Stow and never change the shared layout.
local local_path = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr-local/monitors.lua"
local local_file = io.open(local_path, "r")
if local_file then
    local_file:close()
    dofile(local_path)
    return
end

-- Monitor layout.

hl.monitor({ output = "DP-1", mode = "1920x1080@170", position = "1600x0", scale = "1" })
hl.monitor({ output = "eDP-1", mode = "2880x1800@120", position = "0x120", scale = "1.8" })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
