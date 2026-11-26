#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"

if [ "${1:-}" = --profile ]; then
    [ "$#" -ge 2 ] || {
        echo "Usage: arch.sh --profile hyprland [additional-package ...]" >&2
        exit 2
    }
    profile=$2
    shift 2
    case "$profile" in
        hyprland)
            run_as_root pacman -S --needed \
                git stow \
                hyprland quickshell hypridle hyprpaper \
                xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
                hyprpolkitagent \
                networkmanager bluez bluez-utils blueman power-profiles-daemon \
                pipewire wireplumber pipewire-pulse \
                brightnessctl playerctl grim slurp wl-clipboard wtype \
                kitty fish starship fastfetch \
                fcitx5 fcitx5-gtk fcitx5-qt fcitx5-anthy \
                python imagemagick librsvg xorg-xhost \
                "$@"
            ;;
        *)
            echo "Unsupported Arch package profile: $profile" >&2
            exit 2
            ;;
    esac
    exit 0
fi

run_as_root pacman -S --needed git stow "$@"
