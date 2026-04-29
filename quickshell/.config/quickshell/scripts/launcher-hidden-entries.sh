#!/bin/sh

set -eu

current_desktop="${XDG_CURRENT_DESKTOP:-}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
seen_ids=""

matches_current_desktop() {
    list=${1:-}
    [ -n "$list" ] || return 1

    old_ifs=$IFS
    IFS=';'
    set -- $list
    IFS=$old_ifs

    for desktop in "$@"; do
        [ -n "$desktop" ] || continue
        case ":$current_desktop:" in
            *":$desktop:"*) return 0 ;;
        esac
    done

    return 1
}

field_value() {
    file=$1
    key=$2
    sed -n "s/^${key}=//p" "$file" | head -n 1
}

scan_file() {
    file=$1
    entry_id=${file##*/}

    case ":$seen_ids:" in
        *":$entry_id:"*) return 0 ;;
    esac
    seen_ids="${seen_ids}${seen_ids:+:}$entry_id"

    hidden=$(field_value "$file" "Hidden" | tr '[:upper:]' '[:lower:]')
    nodisplay=$(field_value "$file" "NoDisplay" | tr '[:upper:]' '[:lower:]')
    only_show_in=$(field_value "$file" "OnlyShowIn")
    not_show_in=$(field_value "$file" "NotShowIn")

    case "$hidden" in
        true|1|yes)
            printf '%s\n' "$entry_id"
            return 0
            ;;
    esac

    case "$nodisplay" in
        true|1|yes)
            printf '%s\n' "$entry_id"
            return 0
            ;;
    esac

    if [ -n "$only_show_in" ] && ! matches_current_desktop "$only_show_in"; then
        printf '%s\n' "$entry_id"
        return 0
    fi

    if [ -n "$not_show_in" ] && matches_current_desktop "$not_show_in"; then
        printf '%s\n' "$entry_id"
    fi
}

scan_dir() {
    dir=$1
    [ -d "$dir" ] || return 0

    for file in "$dir"/*.desktop; do
        [ -e "$file" ] || continue
        scan_file "$file"
    done
}

scan_dir "$data_home/applications"

old_ifs=$IFS
IFS=':'
for base_dir in $data_dirs; do
    scan_dir "$base_dir/applications"
done
IFS=$old_ifs

scan_dir "$HOME/.local/share/flatpak/exports/share/applications"
scan_dir "/var/lib/flatpak/exports/share/applications"
