#!/bin/sh

set -eu

if [ "$(uname -s)" != "FreeBSD" ]; then
    echo "This setup is only supported on FreeBSD." >&2
    exit 1
fi

if ! command -v doas >/dev/null 2>&1; then
    echo "doas is required to configure realtime scheduling." >&2
    exit 1
fi

target_user=${1:-${DOAS_USER:-${SUDO_USER:-${USER:-}}}}

if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
    echo "Pass the non-root desktop user as the first argument." >&2
    exit 1
fi

if ! pw usershow "$target_user" >/dev/null 2>&1; then
    echo "Unknown user: $target_user" >&2
    exit 1
fi

realtime_group=$(pw groupshow realtime 2>/dev/null || true)
if [ -z "$realtime_group" ]; then
    echo "The standard FreeBSD realtime group is missing." >&2
    exit 1
fi

realtime_gid=$(printf '%s\n' "$realtime_group" | awk -F: '{ print $3 }')
if [ "$realtime_gid" != "47" ]; then
    echo "The realtime group has GID $realtime_gid; expected the FreeBSD standard GID 47." >&2
    exit 1
fi

# mac_priority(4) is a loader module. sysrc updates the existing key instead of
# appending duplicates, so this remains safe to rerun.
doas sysrc -f /boot/loader.conf mac_priority_load=YES

if ! kldstat -m mac_priority >/dev/null 2>&1; then
    doas kldload mac_priority
fi

if ! id -Gn "$target_user" | tr ' ' '\n' | grep -qx realtime; then
    doas pw groupmod realtime -m "$target_user"
fi

if [ "$(sysctl -n security.mac.priority.realtime)" != "1" ]; then
    echo "mac_priority loaded, but its realtime policy is disabled." >&2
    exit 1
fi

if [ "$(sysctl -n security.mac.priority.realtime_gid)" != "$realtime_gid" ]; then
    echo "mac_priority is not configured for the realtime group's GID." >&2
    exit 1
fi

# Run with a newly initialized supplementary-group list. Existing sessions do
# not gain newly assigned groups until the user logs in again.
if ! doas /usr/bin/su -m "$target_user" -c 'exec rtprio 31 /usr/bin/true'; then
    echo "Realtime scheduling verification failed for $target_user." >&2
    exit 1
fi

echo "Realtime scheduling is configured and verified for $target_user."
echo "Log out completely and back in before starting Hyprland again."
