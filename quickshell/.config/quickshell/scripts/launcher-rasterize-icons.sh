#!/usr/bin/env sh

set -eu

cache_dir="${1:-}"
if [ -z "$cache_dir" ]; then
    exit 0
fi
shift || true

mkdir -p "$cache_dir" || exit 0

gtk_icon_theme() {
    for settings in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
        [ -r "$settings" ] || continue

        value="$(awk -F= '/^[[:space:]]*gtk-icon-theme-name[[:space:]]*=/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$settings" 2>/dev/null || true)"
        if [ -n "$value" ]; then
            printf '%s\n' "$value"
            return
        fi
    done

    if command -v gsettings >/dev/null 2>&1; then
        gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/^'//; s/'$//"
    fi
}

theme_roots() {
    theme="$1"
    [ -n "$theme" ] || return

    for base in "$HOME/.local/share/icons/$theme" "$HOME/.icons/$theme" "/usr/local/share/icons/$theme" "/usr/share/icons/$theme"; do
        [ -d "$base" ] && printf '%s\n' "$base"
    done
}

theme_inherits() {
    theme="$1"
    for base in $(theme_roots "$theme"); do
        [ -r "$base/index.theme" ] || continue

        awk -F= '/^[[:space:]]*Inherits[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); gsub(/,/, "\n", $2); print $2; exit }' "$base/index.theme"
        return
    done
}

theme_chain() {
    pending="$1 hicolor Adwaita AdwaitaLegacy"
    seen=""

    while [ -n "$pending" ]; do
        theme="${pending%% *}"
        if [ "$theme" = "$pending" ]; then
            pending=""
        else
            pending="${pending#* }"
        fi

        [ -n "$theme" ] || continue
        case " $seen " in
            *" $theme "*) continue ;;
        esac

        seen="$seen $theme"
        printf '%s\n' "$theme"

        inherits="$(theme_inherits "$theme" | tr '\n' ' ' || true)"
        [ -n "$inherits" ] && pending="$pending $inherits"
    done
}

theme_index_dirs() {
    base="$1"
    [ -r "$base/index.theme" ] || return

    awk -F= '/^[[:space:]]*(Directories|ScaledDirectories)[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); gsub(/,/, "\n", $2); print $2 }' "$base/index.theme"
}

print_readable_icon() {
    base="$1"
    dir="$2"
    name="$3"

    case "$name" in
        *.svg | *.SVG | *.svgz | *.SVGZ | *.png | *.PNG | *.xpm | *.XPM)
            candidate="$base/$dir/$name"
            if [ -r "$candidate" ]; then
                readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate"
                return 0
            fi
            ;;
        *)
            for ext in svg svgz png xpm; do
                candidate="$base/$dir/$name.$ext"
                if [ -r "$candidate" ]; then
                    readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate"
                    return 0
                fi
            done
            ;;
    esac

    return 1
}

find_icon_in_theme() {
    name="$1"
    theme="$2"
    [ -n "$name" ] && [ -n "$theme" ] || return

    for base in $(theme_roots "$theme"); do
        for dir in \
            apps@2x/scalable apps/scalable apps@2x/512 apps/512 apps@2x/256 apps/256 \
            apps@2x/128 apps/128 apps@2x/96 apps/96 apps@2x/64 apps/64 \
            apps@2x/48 apps/48 apps@2x/32 apps/32 apps@2x/22 apps/22 apps@2x/16 apps/16 \
            512x512/apps 256x256/apps 128x128/apps 96x96/apps 64x64/apps 48x48/apps 32x32/apps 22x22/apps 16x16/apps \
            scalable; do
            print_readable_icon "$base" "$dir" "$name" && return
        done

        for dir in $(theme_index_dirs "$base"); do
            case "$dir" in
                *apps* | *Apps* | *applications* | *Applications*)
                    print_readable_icon "$base" "$dir" "$name" && return
                    ;;
            esac
        done

        for dir in $(theme_index_dirs "$base"); do
            print_readable_icon "$base" "$dir" "$name" && return
        done

        case "$name" in
            *.svg | *.SVG | *.svgz | *.SVGZ | *.png | *.PNG | *.xpm | *.XPM)
                candidate="$(find -L "$base" -type f -name "$name" -print -quit 2>/dev/null || true)"
                ;;
            *)
                candidate="$(find -L "$base" -type f \( -name "$name.svg" -o -name "$name.svgz" -o -name "$name.png" -o -name "$name.xpm" \) -print -quit 2>/dev/null || true)"
                ;;
        esac
        if [ -n "$candidate" ] && [ -r "$candidate" ]; then
            readlink -f "$candidate" 2>/dev/null || printf '%s\n' "$candidate"
            return
        fi
    done
}

resolve_icon() {
    icon_name="$1"
    source_path="$2"

    if [ -n "$icon_name" ] && [ "${icon_name#/}" != "$icon_name" ] && [ -r "$icon_name" ]; then
        readlink -f "$icon_name" 2>/dev/null || printf '%s\n' "$icon_name"
        return
    fi

    if [ -n "$icon_name" ] && [ "${icon_name#/}" = "$icon_name" ]; then
        for theme in $theme_list; do
            resolved_icon="$(find_icon_in_theme "$icon_name" "$theme")"
            if [ -n "$resolved_icon" ]; then
                printf '%s\n' "$resolved_icon"
                return
            fi
        done
    fi

    if [ -n "$source_path" ] && [ -r "$source_path" ]; then
        readlink -f "$source_path" 2>/dev/null || printf '%s\n' "$source_path"
    fi
}

hash_cache_key() {
    real_source="$1"
    stat_data="$2"

    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s:%s\n' "$real_source" "$stat_data" | sha256sum | awk '{ print $1 }'
    elif command -v sha256 >/dev/null 2>&1; then
        printf '%s:%s\n' "$real_source" "$stat_data" | sha256 -q
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s:%s\n' "$real_source" "$stat_data" | shasum -a 256 | awk '{ print $1 }'
    elif command -v openssl >/dev/null 2>&1; then
        printf '%s:%s\n' "$real_source" "$stat_data" | openssl dgst -sha256 | awk '{ print $NF }'
    else
        printf '%s:%s\n' "$real_source" "$stat_data" | cksum | awk '{ print $1 }'
    fi
}

rasterize_icon() {
    source_path="$1"
    real_source="$(readlink -f "$source_path" 2>/dev/null || printf '%s' "$source_path")"
    if stat_data="$(stat -Lc '%s:%Y' "$real_source" 2>/dev/null)"; then
        :
    elif stat_data="$(stat -f '%z:%m' "$real_source" 2>/dev/null)"; then
        :
    else
        stat_data="unknown"
    fi

    cache_key="$(hash_cache_key "$real_source" "$stat_data")"
    output_path="$cache_dir/$cache_key.png"
    if [ -s "$output_path" ]; then
        printf '%s\n' "$output_path"
        return
    fi

    tmp_path="$(mktemp "$output_path.XXXXXX" 2>/dev/null || printf '%s.%s' "$output_path" "$$")"
    rm -f "$tmp_path"

    case "$source_path" in
        *.svg | *.SVG | *.svgz | *.SVGZ)
            if command -v rsvg-convert >/dev/null 2>&1; then
                rsvg-convert -w 256 -h 256 -f png -o "$tmp_path" "$source_path" >/dev/null 2>&1 || true
            fi
            ;;
    esac

    if [ ! -s "$tmp_path" ] && command -v magick >/dev/null 2>&1; then
        magick -background none "$source_path" -resize 256x256 -gravity center -extent 256x256 "$tmp_path" >/dev/null 2>&1 || true
    fi

    if [ -s "$tmp_path" ]; then
        mv -f "$tmp_path" "$output_path"
        printf '%s\n' "$output_path"
    else
        rm -f "$tmp_path"
        printf '%s\n' "$source_path"
    fi
}

emit_result() {
    key="$1"
    path="$2"

    [ -n "$key" ] && [ -n "$path" ] && printf '%s\t%s\n' "$key" "$path"
}

cpu_count() {
    value="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
    case "$value" in
        '' | *[!0-9]*) ;;
        *)
            printf '%s\n' "$value"
            return
            ;;
    esac

    value="$(sysctl -n hw.ncpu 2>/dev/null || true)"
    case "$value" in
        '' | *[!0-9]*) printf '4\n' ;;
        *) printf '%s\n' "$value" ;;
    esac
}

theme_list="$(theme_chain "$(gtk_icon_theme)")"
max_jobs="$(cpu_count)"
case "$max_jobs" in
    '' | *[!0-9]*) max_jobs=4 ;;
esac
[ "$max_jobs" -gt 12 ] && max_jobs=12
[ "$max_jobs" -lt 2 ] && max_jobs=2

process_item() {
    item_key="$1"
    icon_name="$2"
    source_path="$3"

    [ -n "$item_key" ] || return

    resolved_path="$(resolve_icon "$icon_name" "$source_path" || true)"
    if [ -n "$resolved_path" ] && [ -r "$resolved_path" ]; then
        emit_result "$item_key" "$(rasterize_icon "$resolved_path")"
    elif [ -n "$source_path" ]; then
        emit_result "$item_key" "$source_path"
    elif [ -n "$icon_name" ] && [ "${icon_name#/}" = "$icon_name" ]; then
        emit_result "$item_key" "image://icon/$icon_name"
    fi
}

active_jobs=0
while [ "$#" -ge 3 ]; do
    process_item "$1" "$2" "$3" &
    active_jobs=$((active_jobs + 1))
    shift 3

    if [ "$active_jobs" -ge "$max_jobs" ]; then
        wait
        active_jobs=0
    fi
done

wait
