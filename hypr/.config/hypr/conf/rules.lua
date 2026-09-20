-- Layer and window rules.

hl.layer_rule({
    name = "quickshell-blur",
    match = { namespace = "quickshell" },
    blur = true,
})

hl.layer_rule({
    name = "qs-bar-blur",
    match = { namespace = "qs-bar-blur" },
    blur = true,
})

hl.layer_rule({
    name = "qs-notification-blur",
    match = { namespace = "qs-notif" },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "qs-launcher-backdrop-blur",
    match = { namespace = "qs-launcher-backdrop" },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "qs-clipboard-backdrop-blur",
    match = { namespace = "qs-clipboard-backdrop" },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "rofi-blur",
    match = { namespace = "rofi" },
    blur = true,
})

hl.layer_rule({
    name = "qs-border-blur",
    match = { namespace = "qs-border" },
    blur = true,
    ignore_alpha = 0.5,
})

hl.layer_rule({
    name = "qs-osd-blur",
    match = { namespace = "^qs-(volume|im|power|battery-warning)-osd$" },
    blur = true,
    ignore_alpha = 0.5,
})

-- Quickshell surfaces animate their own fused panel geometry.
hl.layer_rule({
    name = "quickshell-self-animated",
    match = { namespace = "^qs-.*" },
    no_anim = true,
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

hl.window_rule({
    name = "elio-file-chooser",
    match = { class = "^(file_chooser)$" },
    float = true,
    center = true,
    size = { 1000, 650 },
})
