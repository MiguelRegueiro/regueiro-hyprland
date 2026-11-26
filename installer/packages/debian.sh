#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"

if [ "${1:-}" = --profile ]; then
    [ "$#" -ge 2 ] || {
        echo "Usage: debian.sh --profile hyprland [additional-package ...]" >&2
        exit 2
    }
    profile=$2
    shift 2
    case "$profile" in
        hyprland)
            groups=all
            catalog=$(dirname -- "$0")/profiles/debian.tsv
            if [ "${1:-}" = --select-groups ]; then
                [ "$#" -eq 1 ] || { echo "Usage: debian.sh --profile hyprland --select-groups" >&2; exit 2; }
                select_catalog_groups "$catalog"
                exit 0
            elif [ "${1:-}" = --groups ]; then
                [ "$#" -ge 2 ] || { echo "Usage: debian.sh --profile hyprland [--groups GROUP[,GROUP...]] [additional-package ...]" >&2; exit 2; }
                groups=$2
                shift 2
            elif [ "${1:-}" = --interactive ]; then
                groups=$(select_catalog_groups "$catalog") || exit $?
                shift
            fi
            os_release_file=${TRITON_OS_RELEASE_FILE:-/etc/os-release}
            [ -r "$os_release_file" ] || {
                echo "Cannot identify Debian release: $os_release_file is missing." >&2
                exit 1
            }
            . "$os_release_file"
            if [ "${ID:-}" != debian ] || [ "${VERSION_CODENAME:-}" != trixie ]; then
                echo "The Hyprland package profile currently supports Debian 13 (Trixie) only." >&2
                exit 2
            fi
            if ! command -v apt-cache >/dev/null 2>&1; then
                echo "Enable Debian's official trixie-backports repository and run 'sudo apt update' before selecting this profile. No packages were installed." >&2
                exit 2
            fi
            for package in hyprland quickshell hypridle hyprpaper xdg-desktop-portal-hyprland hyprpolkitagent; do
                if ! apt-cache policy "$package" 2>/dev/null | grep -F 'trixie-backports' >/dev/null; then
                    echo "Enable Debian's official trixie-backports repository and run 'sudo apt update' before selecting this profile. No packages were installed." >&2
                    exit 2
                fi
            done
            install_catalog debian-backports "$catalog" "$groups" "$@"
            ;;
        *)
            echo "Unsupported Debian package profile: $profile" >&2
            exit 2
            ;;
    esac
    exit 0
fi

install_catalog debian "$(dirname -- "$0")/profiles/debian.tsv" bootstrap "$@"
