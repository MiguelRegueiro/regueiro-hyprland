#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper=$repo_dir/desktop/platforms/freebsd/libexec/triton-privileged
network=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-network
power_profile=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-power-profile
power=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-power
drives=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-drives
drive_eject=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-drive-eject
bluetooth=$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-bluetooth
wifi_backend=$repo_dir/desktop/quickshell/.config/quickshell/services/backends/wifi/freebsd/WifiBackend.qml
output=$(mktemp "${TMPDIR:-/tmp}/triton-helper-output.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

sh -n "$helper" "$network" "$power_profile" "$power" "$drives" "$drive_eject" "$bluetooth" \
    "$repo_dir/installer/platforms/freebsd/install-privileged-helper.sh"

if "$helper" wifi profiles >"$output" 2>&1; then
    echo "Privileged helper accepted a non-root invocation." >&2
    exit 1
fi
if ! grep -F 'must run as root' "$output" >/dev/null; then
    echo "Privileged helper did not reject the caller before dispatch." >&2
    exit 1
fi

if rg -n 'doas[[:space:]]+sh[[:space:]]+-c|doas[[:space:]]+"\$0"|root-update|doas[[:space:]]+(service|pkill|ifconfig|dhclient|route|shutdown|umount|usbconfig|camcontrol|bluetooth-config)' \
    "$network" "$power_profile" "$power" "$drives" "$drive_eject" "$bluetooth" >/dev/null; then
    echo "A FreeBSD adapter still escalates a user-writable script or shell." >&2
    exit 1
fi
if rg -n 'args\.push\(password|connect.*PASSWORD' "$wifi_backend" "$network" >/dev/null; then
    echo "Wi-Fi password still appears as a process argument." >&2
    exit 1
fi
if ! rg -n 'stdinEnabled|pendingPassword|write\(' "$wifi_backend" >/dev/null; then
    echo "Wi-Fi password is not passed through the process stdin channel." >&2
    exit 1
fi

echo "FreeBSD privileged-boundary checks passed (native actions require FreeBSD validation)."
