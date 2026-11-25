# Linux services

Linux-specific command helpers used by Triton Desktop belong here, shared by
compositor integrations. The QuickShell QML adapters that call these helpers
live beside their service interfaces under `services/backends/`.
Per-distribution package names belong in `installer/packages/`.

The Quickshell network, brightness, battery, power-profile, and Wi-Fi backend
QML files live beside their shared service interfaces. `triton-linux-power`
owns Linux systemd and logind power commands;
`triton-linux-service` owns user service-manager and activation-environment
operations. Fcitx input switching and Bluetooth power commands are also
provided by this package. `triton-linux-system-details` supplies Linux CPU and
memory statistics to the shared system-details service. `triton-linux-drives`
supplies Linux device discovery, mounting, and eject operations to the shared
external-drive service.
