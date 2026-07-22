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

# Portal-spawned windows can fall back to a monitor's default workspace.
# Move the exact chooser window back to the workspace that was active at launch.
active_workspace() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    hyprctl activeworkspace -j 2>/dev/null | jq -r 'select(.id != null and .id > 0) | .id' 2>/dev/null || true
}

watch_and_place_chooser() {
    local title="$1"
    local workspace="$2"
    local addr=""

    [[ -n "$workspace" ]] || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    for _ in {1..80}; do
        addr="$(
            hyprctl clients -j 2>/dev/null |
                jq -r --arg title "$title" '
                    first(.[] | select(
                        (.class == "file_chooser" or .initialClass == "file_chooser")
                        and (.title == $title or .initialTitle == $title)
                    ) | .address) // empty
                ' 2>/dev/null || true
        )"

        if [[ -n "$addr" ]]; then
            hyprctl dispatch movetoworkspacesilent "$workspace,address:$addr" >/dev/null 2>&1 || true
            hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
            return 0
        fi

        sleep 0.05
    done
}

run_chooser() {
    local start="$1"
    local workspace title watcher_pid status

    workspace="$(active_workspace)"
    title="termfilechooser-$$"
    status=0

    watch_and_place_chooser "$title" "$workspace" &
    watcher_pid="$!"

    kitty --class=file_chooser --title "$title" -e "$chooser_cmd" --chooser-file "$tmp" "$start" || status="$?"

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    return "$status"
}

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
    run_chooser "$start"

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

run_chooser "$start"

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
