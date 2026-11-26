#!/bin/sh
set -eu

profile=
if [ "${1:-}" = --profile ]; then
    if [ "$#" -lt 2 ]; then
        echo "Usage: ./install.sh packages [package ...] | --profile NAME [package ...]" >&2
        exit 2
    fi
    profile=$2
    shift 2
fi

os=$(uname -s)
if [ "$os" = FreeBSD ]; then
    script=freebsd.sh
else
    os_release_file=${TRITON_OS_RELEASE_FILE:-/etc/os-release}
    if [ ! -r "$os_release_file" ]; then
        echo "Cannot identify Linux distribution: $os_release_file is missing." >&2
        exit 1
    fi
    . "$os_release_file"
    id=${ID:-}
    id_like=${ID_LIKE:-}
    case " $id $id_like " in
        *' arch '*|*' cachyos '*) script=arch.sh ;;
        *' fedora '*) script=fedora.sh ;;
        *' debian '*|*' ubuntu '*) script=debian.sh ;;
        *' void '*) script=void.sh ;;
        *) echo "Unsupported distribution: $id (ID_LIKE: ${id_like:-none})" >&2; exit 1 ;;
    esac
fi

if [ -n "$profile" ]; then
    case "$script:$profile" in
        arch.sh:hyprland)
            exec "$(dirname "$0")/$script" --profile "$profile" "$@"
            ;;
        debian.sh:hyprland)
            exec "$(dirname "$0")/$script" --profile "$profile" "$@"
            ;;
        fedora.sh:hyprland)
            echo "The Hyprland profile is not available on Fedora yet: the required compositor, idle, and wallpaper packages do not have matching builds for current Fedora releases. No packages were installed." >&2
            exit 2
            ;;
        *)
            echo "Package profile '$profile' is not supported on this platform yet." >&2
            exit 2
            ;;
    esac
fi

exec "$(dirname "$0")/$script" "$@"
