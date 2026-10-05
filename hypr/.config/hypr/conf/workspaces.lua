-- Workspace rules.

hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true, default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "eDP-1", persistent = true, default = true })

-- The laptop owns workspace 10 while docked, but standalone sessions should
-- begin on the familiar 1–5 set. Do this once after output discovery; changing
-- workspace rules on later hot-plug events would make an active session less
-- predictable.
hl.on("hyprland.start", function()
    hl.timer(function()
        if hl.get_monitor("DP-1") == nil and hl.get_monitor("eDP-1") ~= nil then
            hl.dispatch(hl.dsp.focus({ workspace = "1" }))
        end
    end, { timeout = 1500, type = "oneshot" })
end)
