hl.layer_rule({
    name = "quickshell-blur",
    match = { namespace = "quickshell" },
    blur = true,
})

hl.layer_rule({
    name = "qs-border-noblur",
    match = { namespace = "qs-border" },
    blur = false,
})

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
