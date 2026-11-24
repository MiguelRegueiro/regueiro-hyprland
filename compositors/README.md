# Compositors

Compositor integrations own session startup, bindings, monitor/window actions,
and compositor-specific IPC. They connect the desktop UI to platform service
contracts; they must not implement OS hardware access themselves.

Hyprland is the supported integration today. `niri/` is reserved for a future
integration and is intentionally not advertised as usable yet.
