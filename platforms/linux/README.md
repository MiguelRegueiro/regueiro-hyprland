# Linux services

Linux-specific hardware and desktop service adapters belong here, shared by
compositor integrations. Keep per-distribution package names in
`installer/packages/`; keep service behavior such as brightness, networking,
and power behind stable commands or D-Bus interfaces consumed by the desktop.

The current Hyprland setup still has several adapters embedded in its scripts
and QuickShell services. Move those behind this boundary incrementally while
preserving the deployed command paths until each adapter is migrated.
