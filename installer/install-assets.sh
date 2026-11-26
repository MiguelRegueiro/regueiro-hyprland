#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
font_source=$repo_dir/desktop/assets/fonts
cursor_source=$repo_dir/desktop/assets/icons/Bibata-Modern-Classic
font_target=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/triton-desktop
cursor_target=${XDG_DATA_HOME:-$HOME/.local/share}/icons/Bibata-Modern-Classic
check_only=no
[ "${1:-}" != --check ] || check_only=yes
[ "$#" -le 1 ] || { echo "Usage: install-assets.sh [--check]" >&2; exit 2; }

link_asset() {
    source=$1
    target=$2
    mkdir -p "$(dirname -- "$target")"
    if [ -L "$target" ]; then
        linked=$(realpath "$target")
        expected=$(realpath "$source")
        [ "$linked" = "$expected" ] && return 0
        if [ "$check_only" = yes ]; then
            echo "Asset install conflict: $target links somewhere else." >&2
            return 1
        fi
        echo "Asset install conflict: $target links somewhere else." >&2
        return 1
    fi
    if [ -e "$target" ]; then
        # Respect themes and fonts installed manually or by another package.
        return 0
    fi
    ln -s "$source" "$target"
}

[ "$check_only" = yes ] && exit 0
link_asset "$font_source" "$font_target"
link_asset "$cursor_source" "$cursor_target"
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_target" >/dev/null 2>&1 || true
fi
