#!/bin/sh
set -eu

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
exec "$(dirname "$0")/$script" "$@"
