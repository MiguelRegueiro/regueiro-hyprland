-- Machine-local settings live outside Stow and never change the shared layout.
local local_path = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr-local/monitors.lua"
local local_file = io.open(local_path, "r")
if local_file then
    local_file:close()
    dofile(local_path)
    return
end

-- Generic first-run baseline: ask connected outputs for their preferred mode
-- and let Hyprland arrange them. The Display settings page saves per-machine
-- resolutions, scales, transforms, and positions outside the shared config.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
