hl.workspace_rule({
    workspace = "f[1]",
    gaps_out = 14,
    gaps_in = 4,
})

for workspace = 1, 5 do
    hl.workspace_rule({
        workspace = tostring(workspace),
        monitor = "eDP-1",
        persistent = true,
        default = workspace == 1,
    })
end
