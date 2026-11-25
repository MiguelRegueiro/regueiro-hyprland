# Desktop operating-system helpers

This folder contains OS-specific command helpers and native hardware bridges
used by Triton Desktop. The Quickshell-facing QML adapters live with their
services under `desktop/quickshell/.config/quickshell/services/backends/`.

- `linux/` contains Linux helper commands shared across compositors.
- `freebsd/` contains FreeBSD helper commands and the native hardware bridge.
- `src/` holds source files compiled by platform-specific installers; it stays
  outside the Stow package roots.
- `docs/` holds platform-specific setup and validation notes.

Distribution-specific package names and installation remain in
`installer/packages/`.
