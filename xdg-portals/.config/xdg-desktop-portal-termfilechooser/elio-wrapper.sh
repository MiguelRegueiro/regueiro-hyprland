#!/usr/bin/env bash
set -euo pipefail

multiple="${1:-0}"
directory="${2:-0}"
save="${3:-0}"
path="${4:-}"
out="${5:?missing output file}"
debug="${6:-0}"

[[ "$debug" == "1" ]] && set -x

tmp="$(mktemp)"
chooser_cmd="${TERMFILECHOOSER_FM:-elio}"
trap 'rm -f "$tmp"' EXIT

default_dir="${HOME:-/tmp}"
start="$default_dir"
suggested_name="untitled"

if [[ -n "$path" ]]; then
    if [[ -d "$path" ]]; then
        start="$path"
    else
        parent="$(dirname -- "$path")"
        name="$(basename -- "$path")"

        [[ -n "$name" && "$name" != "." && "$name" != "/" ]] && suggested_name="$name"
        [[ "$parent" != "." && -d "$parent" ]] && start="$parent"
    fi
fi

if [[ "$save" == "1" ]]; then
    kitty --class=file_chooser --title termfilechooser -e "$chooser_cmd" --chooser-file "$tmp" "$start"

    choice=""
    IFS= read -r choice < "$tmp" || true
    [[ -n "$choice" ]] || exit 1

    if [[ -d "$choice" ]]; then
        if [[ "$choice" == "/" ]]; then
            printf '/%s\n' "$suggested_name" > "$out"
        else
            printf '%s/%s\n' "${choice%/}" "$suggested_name" > "$out"
        fi
    else
        printf '%s\n' "$choice" > "$out"
    fi

    exit 0
fi

if [[ -n "$path" && "$directory" != "1" && "$multiple" != "1" ]]; then
    start="$path"
fi

kitty --class=file_chooser --title termfilechooser -e "$chooser_cmd" --chooser-file "$tmp" "$start"

if [[ "$directory" == "1" ]]; then
    filtered="$(mktemp)"
    trap 'rm -f "$tmp" "$filtered"' EXIT

    while IFS= read -r choice; do
        [[ -n "$choice" ]] || continue

        if [[ -d "$choice" ]]; then
            printf '%s\n' "$choice" >> "$filtered"
        elif [[ -e "$choice" ]]; then
            dirname -- "$choice" >> "$filtered"
        fi
    done < "$tmp"

    [[ -s "$filtered" ]] || exit 1
    cat "$filtered" > "$out"
    exit 0
fi

filtered="$(mktemp)"
trap 'rm -f "$tmp" "$filtered"' EXIT

while IFS= read -r choice; do
    [[ -n "$choice" && ! -d "$choice" ]] && printf '%s\n' "$choice" >> "$filtered"
done < "$tmp"

[[ -s "$filtered" ]] || exit 1
cat "$filtered" > "$out"
