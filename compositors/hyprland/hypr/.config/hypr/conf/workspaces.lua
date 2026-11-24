-- Workspace rules.

hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
-- Display profiles assign the ranges dynamically: 1–9 primary, 10–19 second
-- external, and 20+ laptop. This avoids a docked monitor claiming workspace 1
-- while the laptop is used on its own.
