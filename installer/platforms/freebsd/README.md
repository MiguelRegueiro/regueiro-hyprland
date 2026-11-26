# FreeBSD privileged helper

The network, Bluetooth, power-profile, and shutdown adapters call the fixed helper at
`/usr/local/libexec/triton-privileged`. It accepts only those named operations,
keeps the WPA config under `/usr/local/etc/triton-desktop/` with root ownership
and mode `0600`, and reads a new Wi-Fi password from stdin. Do not add a broad
passwordless `doas` rule for shells, scripts, or package managers.

Review the tracked helper source before installing it. From the repository
checkout, install it explicitly as root:

```sh
doas installer/platforms/freebsd/install-privileged-helper.sh
```

The installer sets the helper owner and mode, and prepares the root-owned
configuration directory. This does not configure `doas`; the system's existing
administrator policy still controls whether the desktop user may run the
helper. The removable-drive fallback uses `doas -n` for the helper, which
validates the requested device and mount-point pair before forcing an unmount
or powering off a USB storage device.

FreeBSD runtime testing is still required before treating these operations as
production-ready.
