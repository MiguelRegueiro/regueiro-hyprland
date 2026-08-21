-- Personal Hyprland desktop config.
-- Split into focused Lua modules under ./conf.

local programs = require("conf.vars")

require("conf.monitors")
require("conf.env")
require("conf.appearance")
require("conf.input")
require("conf.workspaces")
require("conf.rules")
require("conf.binds")(programs)
require("conf.autostart")
