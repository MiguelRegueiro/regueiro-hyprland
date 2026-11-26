#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this helper installer as root (for example, with doas)." >&2
    exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
source_file=$repo_dir/desktop/platforms/freebsd/libexec/triton-privileged
destination=/usr/local/libexec/triton-privileged

[ -f "$source_file" ] || { echo "Privileged helper source is missing." >&2; exit 1; }
install -d -o root -g wheel -m 0755 /usr/local/libexec /usr/local/etc/triton-desktop
install -o root -g wheel -m 0755 "$source_file" "$destination"
chmod 0755 /usr/local/etc/triton-desktop
chown root:wheel /usr/local/etc/triton-desktop
echo "Installed root-owned helper at $destination."
