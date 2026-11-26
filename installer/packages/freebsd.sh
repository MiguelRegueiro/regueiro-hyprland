#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"

if [ "${1:-}" = --profile ]; then
    [ "$#" -ge 2 ] || {
        echo "Usage: freebsd.sh --profile hyprland [additional-package ...]" >&2
        exit 2
    }
    profile=$2
    shift 2
    case "$profile" in
        hyprland)
            groups=all
            catalog=$(dirname -- "$0")/profiles/freebsd.tsv
            if [ "${1:-}" = --groups ]; then
                [ "$#" -ge 2 ] || { echo "Usage: freebsd.sh --profile hyprland [--groups GROUP[,GROUP...]] [additional-package ...]" >&2; exit 2; }
                groups=$2
                shift 2
            elif [ "${1:-}" = --interactive ]; then
                groups=$(select_catalog_groups "$catalog") || exit $?
                shift
            fi
            release=$(uname -r)
            case "$release" in
                14.4-*|14.5-*|15.1-*) ;;
                *)
                    echo "The Hyprland package profile currently supports FreeBSD 14.4, 14.5, and 15.1." >&2
                    exit 2
                    ;;
            esac
            install_catalog freebsd "$catalog" "$groups" "$@"
            ;;
        *)
            echo "Unsupported FreeBSD package profile: $profile" >&2
            exit 2
            ;;
    esac
    exit 0
fi

install_catalog freebsd "$(dirname -- "$0")/profiles/freebsd.tsv" base "$@"
