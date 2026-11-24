#!/bin/sh
set -eu

os=$(uname -s)
if [ "$os" = FreeBSD ]; then
    script=freebsd.sh
else
    if [ ! -r /etc/os-release ]; then
        echo "Cannot identify Linux distribution: /etc/os-release is missing." >&2
        exit 1
    fi
    id=$(. /etc/os-release; printf '%s' "${ID:-}")
    case "$id" in
        arch|cachyos) script=arch.sh ;;
        fedora) script=fedora.sh ;;
        debian|ubuntu|linuxmint|pop) script=debian.sh ;;
        void) script=void.sh ;;
        *) echo "Unsupported distribution: $id" >&2; exit 1 ;;
    esac
fi
exec "$(dirname "$0")/$script" "$@"
