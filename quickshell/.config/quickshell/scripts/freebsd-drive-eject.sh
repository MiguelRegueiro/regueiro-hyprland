#!/bin/sh

set -eu

action="${1:-}"
part="${2:-}"
mountpoint="${3:-}"
disk="${4:-}"

is_mounted() {
    mount | awk -v part="$part" -v mountpoint="$mountpoint" '
        ($1 == part) || (mountpoint != "" && $3 == mountpoint) {
            found = 1
        }
        END {
            exit found ? 0 : 1
        }
    '
}

disk_exists() {
    [ -n "$disk" ] || return 1
    udisksctl info -b "$disk" >/dev/null 2>&1
}

umass_index_for_disk() {
    base="$(basename "$disk")"
    doas -n camcontrol devlist -v 2>/dev/null | awk -v disk="$base" '
        $1 ~ /^scbus[0-9-]+$/ && $3 ~ /^umass-sim[0-9]+$/ {
            umass = $3
            sub(/^umass-sim/, "", umass)
            next
        }
        index($0, "(" disk ",") > 0 {
            print umass
            exit
        }
    '
}

ugen_for_umass() {
    umass="$1"
    [ -n "$umass" ] || return 1
    sysctl -n "dev.umass.${umass}.%location" 2>/dev/null | sed -n 's/.*ugen=\([^ ]*\).*/\1/p'
}

unmount_drive() {
    [ -n "$part" ] || return 1
    if ! is_mounted; then
        return 0
    fi

    if ! udisksctl unmount -b "$part"; then
        [ -n "$mountpoint" ] || return 1
        doas -n umount -f "$mountpoint"
    fi

    if is_mounted; then
        printf '%s\n' "Drive is still mounted"
        return 1
    fi
}

power_off_drive() {
    [ -n "$disk" ] || return 1

    udisksctl power-off -b "$disk" >/dev/null 2>&1 || true
    sleep 0.3
    if ! disk_exists; then
        return 0
    fi

    umass="$(umass_index_for_disk)"
    ugen="$(ugen_for_umass "$umass")"
    [ -n "$ugen" ] || {
        printf '%s\n' "Could not find USB device for $disk"
        return 1
    }

    doas -n usbconfig -d "$ugen" power_off
    sleep 0.3
    if disk_exists; then
        printf '%s\n' "Drive did not power off"
        return 1
    fi
}

case "$action" in
    unmount)
        unmount_drive
        ;;
    eject)
        unmount_drive
        power_off_drive
        ;;
    *)
        printf '%s\n' "Usage: $0 {unmount|eject} partition mountpoint disk" >&2
        exit 64
        ;;
esac
