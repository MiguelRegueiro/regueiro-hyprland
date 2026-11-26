#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
font_source=$repo_dir/desktop/assets/fonts
cursor_source=$repo_dir/desktop/assets/icons/Bibata-Modern-Classic
font_target=${XDG_DATA_HOME:-$HOME/.local/share}/fonts/triton-desktop
cursor_target=${XDG_DATA_HOME:-$HOME/.local/share}/icons/Bibata-Modern-Classic
asset_target=${XDG_DATA_HOME:-$HOME/.local/share}/triton-desktop/assets
check_only=no
[ "${1:-}" != --check ] || check_only=yes
[ "$#" -le 1 ] || { echo "Usage: install-assets.sh [--check]" >&2; exit 2; }
created_links=

rollback_assets() {
    status=$?
    trap - EXIT HUP INT TERM
    if [ "$status" -ne 0 ] && [ -n "$created_links" ]; then
        printf '%s\n' "$created_links" | while IFS= read -r target; do
            [ -n "$target" ] || continue
            case "$target" in
                "$font_target") source=$font_source ;;
                "$cursor_target") source=$cursor_source ;;
                "$asset_target") source=$repo_dir/desktop/assets ;;
                *) continue ;;
            esac
            if [ -L "$target" ] && [ "$(realpath "$target")" = "$(realpath "$source")" ]; then
                rm -f "$target"
            fi
        done
    fi
    exit "$status"
}
trap rollback_assets EXIT
trap 'exit 1' HUP INT TERM

link_asset() {
    source=$1
    target=$2
    parent=$(dirname -- "$target")
    if [ "$check_only" = yes ]; then
        while [ ! -d "$parent" ] && [ "$parent" != / ]; do
            if [ -e "$parent" ] || [ -L "$parent" ]; then
                echo "Asset install conflict: $parent exists but is not a directory." >&2
                return 1
            fi
            parent=$(dirname -- "$parent")
        done
    else
        mkdir -p "$parent"
    fi
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
    if [ "$check_only" = yes ]; then
        return 0
    fi
    ln -s "$source" "$target"
    created_links="${created_links}${target}
"
}

link_asset "$font_source" "$font_target"
link_asset "$cursor_source" "$cursor_target"
link_asset "$repo_dir/desktop/assets" "$asset_target"
[ "$check_only" = yes ] && exit 0
if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_target" >/dev/null 2>&1 || true
fi
