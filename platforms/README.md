# Platform adapters

Platform code owns operating-system services and hardware APIs. Desktop UI
must call stable desktop services and must not branch on the distribution.

- `linux/` is the home for Linux service adapters shared across compositors.
- `freebsd/` is the home for native FreeBSD service adapters.

Add an adapter when a desktop feature needs a platform-specific operation.
Keep its QML-facing contract in `desktop/quickshell/`; select the platform
implementation during session startup. Do not copy distro-specific behavior
into shared controls.
