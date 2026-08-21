-- Laptop panel and external display. Other monitors use automatic layout.
hl.monitor({
    output = "DP-1",
    mode = "1920x1080@170",
    position = "1728x0",
    scale = 1,
})

hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x120",
    scale = 1.25,
})

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})
