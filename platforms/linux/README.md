# Linux services

Linux-specific hardware and desktop service adapters belong here, shared by
compositor integrations. Keep per-distribution package names in
`installer/packages/`; keep service behavior such as brightness, networking,
and power behind stable commands or D-Bus interfaces consumed by the desktop.

The Linux Quickshell network, brightness, battery, and power-profile backends
are deployed as a platform package and loaded through shared service
contracts. `triton-linux-power` owns Linux systemd and logind power commands;
`triton-linux-service` owns user service-manager and activation-environment
operations. Fcitx input switching and Bluetooth power commands are also
provided by this package. Linux system-statistics and external-drive behavior
remain to be extracted from the desktop services.
