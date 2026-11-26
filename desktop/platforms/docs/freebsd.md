# FreeBSD desktop helpers

The shared battery service uses `apm` and `acpiconf` through
`triton-freebsd-battery`. The shared brightness service uses the persistent
native backlight bridge from `../src/freebsd/triton-freebsd-hardware.c`.
Shared audio controls use PipeWire/WirePlumber through the common
`AudioService`.
Shared network and Wi-Fi UI uses `triton-freebsd-network` for interface status,
Wi-Fi scanning, saved profiles, connection, and Ethernet toggling.
The shared Bluetooth page uses `triton-freebsd-bluetooth` for controller state,
device connections, and the native settings action.
`triton-freebsd-system-details` normalizes CPU, memory, swap, and process data
for the shared system-details UI.
`triton-freebsd-drives` supplies UDisks discovery, mount, unmount, and eject
operations for the shared external-drive menu.
The shared power-profile selector uses `triton-freebsd-power-profile` to apply
`powerd` flags and Intel EPP values.
Shared reboot and poweroff actions use `triton-freebsd-power`, which invokes
the root-owned Triton allowlist helper through `doas`. Configure an appropriate
administrator policy on the target system; without it the command fails closed.

On FreeBSD, `./install.sh` selects this Stow package and compiles the bridge
into `~/.local/bin/triton-freebsd-hardware`. The bridge targets the device paths
validated by the existing FreeBSD branch (`/dev/backlight/backlight0` and
`/dev/mixer0`); machines with different device paths need adaptation.

The FreeBSD adapters are not runtime-validated by the Linux test host. Confirm
device permissions, backlight behavior, PipeWire audio, native portal/polkit
startup, and service behavior on the target FreeBSD machine before relying on
them. Idle policy, automatic suspend, and resume actions are currently exposed
only by the Linux backend; Hyprland startup skips the Linux power daemon on BSD.
