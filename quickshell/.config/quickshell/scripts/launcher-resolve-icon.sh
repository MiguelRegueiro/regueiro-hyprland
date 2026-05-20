#!/bin/sh

set -eu

name=${1:-}
[ -z "$name" ] && exit 0

case "$name" in
    /*)
        [ -e "$name" ] && printf '%s' "$name"
        exit 0
        ;;
esac

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

icon_roots=""
for d in "$data_home/icons" "$HOME/.icons"; do
    [ -d "$d" ] && icon_roots="$icon_roots $d"
done

pixmap_dirs=""
old_ifs=$IFS
IFS=':'
set -- $data_dirs
IFS=$old_ifs
for base_dir in "$@"; do
    [ -d "$base_dir/icons" ] && icon_roots="$icon_roots $base_dir/icons"
    [ -d "$base_dir/pixmaps" ] && pixmap_dirs="$pixmap_dirs $base_dir/pixmaps"
done

for d in "$HOME/.local/share/flatpak/exports/share/icons" "/var/lib/flatpak/exports/share/icons"; do
    [ -d "$d" ] && icon_roots="$icon_roots $d"
done

emit() {
    printf '%s' "$1"
    exit 0
}

for root in $icon_roots; do
    [ -d "$root/hicolor" ] || continue
    f="$root/hicolor/scalable/apps/$name.svg"
    [ -f "$f" ] && emit "$f"
    for size in 512x512 256x256 192x192 128x128 96x96 64x64 48x48 32x32 24x24 22x22 16x16; do
        f="$root/hicolor/$size/apps/$name.png"
        [ -f "$f" ] && emit "$f"
    done
done

for d in $pixmap_dirs; do
    for ext in svg png xpm; do
        f="$d/$name.$ext"
        [ -f "$f" ] && emit "$f"
    done
done

find_first() {
    # shellcheck disable=SC2086
    find "$@" \( -name "$name.svg" -o -name "$name.png" -o -name "$name.xpm" \) -print -quit 2>/dev/null
}

if [ -n "$icon_roots" ]; then
    # shellcheck disable=SC2086
    match=$(find_first $icon_roots -follow -maxdepth 6 -path '*/apps/*')
    [ -n "$match" ] && emit "$match"
fi

if [ -n "$icon_roots" ]; then
    # shellcheck disable=SC2086
    match=$(find_first $icon_roots -follow -maxdepth 8)
    [ -n "$match" ] && emit "$match"
fi
