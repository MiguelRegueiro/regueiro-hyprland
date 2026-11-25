# Linux services

Linux-specific hardware and desktop service adapters belong here, shared by
compositor integrations. Keep per-distribution package names in
`installer/packages/`; keep service behavior such as brightness, networking,
and power behind stable commands or D-Bus interfaces consumed by the desktop.

The Linux Quickshell network, brightness, battery, and power-profile backends
are deployed as a platform package and loaded through shared service
contracts. `triton-linux-power` owns Linux systemd and logind power commands
used by the Hyprland power policy. The current Hyprland setup still has other
adapters embedded in its scripts and QuickShell services. Move those behind
this boundary incrementally while preserving deployed command paths until each
adapter is migrated.
