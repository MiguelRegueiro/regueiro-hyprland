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
            groups=all
            catalog=$(dirname -- "$0")/profiles/arch.tsv
            if [ "${1:-}" = --select-groups ]; then
                [ "$#" -eq 1 ] || { echo "Usage: arch.sh --profile hyprland --select-groups" >&2; exit 2; }
                select_catalog_groups "$catalog"
                exit 0
            elif [ "${1:-}" = --groups ]; then
                [ "$#" -ge 2 ] || { echo "Usage: arch.sh --profile hyprland [--groups GROUP[,GROUP...]] [additional-package ...]" >&2; exit 2; }
                groups=$2
                shift 2
            elif [ "${1:-}" = --interactive ]; then
                groups=$(select_catalog_groups "$catalog") || exit $?
                shift
            fi
            install_catalog arch "$catalog" "$groups" "$@"
            ;;
        *)
            echo "Unsupported Arch package profile: $profile" >&2
            exit 2
            ;;
    esac
    exit 0
fi

install_catalog arch "$(dirname -- "$0")/profiles/arch.tsv" bootstrap "$@"
