-- Personal Hyprland desktop config.
-- Make local modules resolvable even when Hyprland does not add this file's
-- directory to Lua's package path (notably during config reloads).
local source = debug.getinfo(1, "S").source
local config_dir = source:sub(1, 1) == "@" and source:sub(2):match("^(.*)/") or nil
if config_dir then
    package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path
end

require("conf.monitors")
require("conf.env")
require("conf.appearance")
require("conf.input")
require("conf.workspaces")
require("conf.rules")
require("conf.binds")
require("conf.autostart")
