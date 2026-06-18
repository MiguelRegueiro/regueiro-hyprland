#!/bin/sh

set -eu

current_desktop="${XDG_CURRENT_DESKTOP:-}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

scan_dir() {
    dir=$1
    [ -d "$dir" ] || return 0

    find "$dir" -maxdepth 1 -type f -name '*.desktop' -print
}

{
    scan_dir "$data_home/applications"

    old_ifs=$IFS
    IFS=':'
    for base_dir in $data_dirs; do
        scan_dir "$base_dir/applications"
    done
    IFS=$old_ifs

    scan_dir "$HOME/.local/share/flatpak/exports/share/applications"
    scan_dir "/var/lib/flatpak/exports/share/applications"
} | awk -v current_desktop="$current_desktop" '
BEGIN {
    split(current_desktop, desktop_values, ":")
    for (desktop_index in desktop_values) {
        if (desktop_values[desktop_index] != "")
            desktops[desktop_values[desktop_index]] = 1
    }
}

function trim(value) {
    sub(/^[ \t\r\n]+/, "", value)
    sub(/[ \t\r\n]+$/, "", value)
    return value
}

function basename(path, parts_count, parts) {
    parts_count = split(path, parts, "/")
    return parts[parts_count]
}

function matches_current_desktop(list, parts_count, parts, part_index, desktop) {
    if (list == "")
        return 0

    parts_count = split(list, parts, ";")
    for (part_index = 1; part_index <= parts_count; part_index += 1) {
        desktop = trim(parts[part_index])
        if (desktop != "" && desktops[desktop])
            return 1
    }

    return 0
}

function scan_file(file, entry_id, line, hidden, nodisplay, only_show_in, not_show_in) {
    entry_id = basename(file)
    if (seen_ids[entry_id])
        return
    seen_ids[entry_id] = 1

    hidden = ""
    nodisplay = ""
    only_show_in = ""
    not_show_in = ""

    while ((getline line < file) > 0) {
        sub(/\r$/, "", line)
        if (hidden == "" && index(line, "Hidden=") == 1)
            hidden = trim(substr(line, 8))
        else if (nodisplay == "" && index(line, "NoDisplay=") == 1)
            nodisplay = trim(substr(line, 11))
        else if (only_show_in == "" && index(line, "OnlyShowIn=") == 1)
            only_show_in = trim(substr(line, 12))
        else if (not_show_in == "" && index(line, "NotShowIn=") == 1)
            not_show_in = trim(substr(line, 11))
    }
    close(file)

    hidden = tolower(hidden)
    nodisplay = tolower(nodisplay)

    if (hidden == "true" || hidden == "1" || hidden == "yes") {
        print entry_id
        return
    }

    if (nodisplay == "true" || nodisplay == "1" || nodisplay == "yes") {
        print entry_id
        return
    }

    if (only_show_in != "" && !matches_current_desktop(only_show_in)) {
        print entry_id
        return
    }

    if (not_show_in != "" && matches_current_desktop(not_show_in))
        print entry_id
}

{
    scan_file($0)
}
'
