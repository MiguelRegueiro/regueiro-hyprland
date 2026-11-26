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
            run_as_root apt install -t trixie-backports \
                git stow \
                hyprland quickshell hypridle hyprpaper \
                xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
                hyprpolkitagent \
                network-manager bluez blueman power-profiles-daemon \
                pipewire wireplumber pipewire-pulse \
                brightnessctl playerctl grim slurp wl-clipboard wtype \
                kitty fish starship fastfetch \
                fcitx5 fcitx5-frontend-all fcitx5-anthy \
                python3 python-is-python3 procps imagemagick librsvg2-bin x11-xserver-utils \
                "$@"
            ;;
        *)
            echo "Unsupported Debian package profile: $profile" >&2
            exit 2
            ;;
    esac
    exit 0
fi

run_as_root apt install git stow "$@"
