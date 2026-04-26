#!/bin/bash

action="${1:-cycle-next}"
shift || true

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
profile_path="${FCITX5_PROFILE_PATH:-$config_home/fcitx5/profile}"
fcitx_remote="${FCITX5_REMOTE_BIN:-}"
spanish_method="${INPUT_METHOD_SPANISH_ID:-keyboard-es}"
japanese_method="${INPUT_METHOD_JAPANESE_ID:-mozc}"

if [ -z "$fcitx_remote" ]; then
    fcitx_remote="$(command -v fcitx5-remote 2>/dev/null || true)"
fi

print_usage() {
    echo "Usage: $0 {describe|status|current|list|switch <imname>|cycle-next|toggle|spanish|japanese}" >&2
}

have_remote() {
    [ -n "$fcitx_remote" ] && [ -x "$fcitx_remote" ]
}

remote_check_rc() {
    local rc

    if ! have_remote; then
        printf '127\n'
        return
    fi

    rc="$(
        {
            "$fcitx_remote" --check >/dev/null 2>&1
            printf '%s' "$?"
        } 2>/dev/null
    )"

    printf '%s\n' "${rc:-1}"
}

remote_is_running() {
    [ "$(remote_check_rc)" = "0" ]
}

profile_default_group() {
    [ -r "$profile_path" ] || return 0

    awk '
        BEGIN { in_order = 0 }
        /^\[GroupOrder\]$/ {
            in_order = 1
            next
        }
        /^\[/ {
            if (in_order)
                exit
        }
        in_order && $0 ~ /^[0-9]+=.+$/ {
            sub(/^[0-9]+=/, "")
            print
            exit
        }
    ' "$profile_path"
}

profile_methods_for_group() {
    local target_group="$1"

    [ -r "$profile_path" ] || return 0
    [ -n "$target_group" ] || return 0

    awk -v target_group="$target_group" '
        /^\[/ {
            section = $0
            gsub(/^\[|\]$/, "", section)

            if (section ~ /^Groups\/[0-9]+$/) {
                group_section = section
                in_group = 1
                in_item = 0
            } else if (section ~ /^Groups\/[0-9]+\/Items\/[0-9]+$/) {
                split(section, parts, "/")
                item_group_section = "Groups/" parts[2]
                in_group = 0
                in_item = (group_names[item_group_section] == target_group)
            } else {
                in_group = 0
                in_item = 0
            }

            next
        }

        in_group && /^Name=/ {
            group_names[group_section] = substr($0, 6)
            next
        }

        in_item && /^Name=/ {
            print substr($0, 6)
        }
    ' "$profile_path"
}

resolved_group_name() {
    local group_name=""

    if remote_is_running; then
        if group_name="$("$fcitx_remote" -q 2>/dev/null)"; then
            :
        else
            group_name=""
        fi
    fi

    if [ -n "$group_name" ]; then
        printf '%s\n' "$group_name"
        return 0
    fi

    profile_default_group
}

array_contains() {
    local needle="$1"
    shift
    local item

    for item in "$@"; do
        if [ "$item" = "$needle" ]; then
            return 0
        fi
    done

    return 1
}

load_group_methods() {
    local group_name="$1"
    profile_methods_for_group "$group_name"
}

load_current_method() {
    local current_method=""

    if ! have_remote || ! remote_is_running; then
        return 1
    fi

    if current_method="$("$fcitx_remote" -n 2>/dev/null)"; then
        if [ -n "$current_method" ]; then
            printf '%s\n' "$current_method"
            return 0
        fi
    fi

    return 1
}

load_runtime_state() {
    local state=""

    if ! have_remote; then
        printf 'missing unknown\n'
        return 0
    fi

    if ! remote_is_running; then
        printf 'unavailable unknown\n'
        return 0
    fi

    if ! state="$("$fcitx_remote" 2>/dev/null)"; then
        echo "Failed to query fcitx5 state" >&2
        return 1
    fi

    case "$state" in
        0)
            printf 'closed closed\n'
            ;;
        1)
            printf 'ok inactive\n'
            ;;
        2)
            printf 'ok active\n'
            ;;
        *)
            echo "Unexpected fcitx5-remote state: $state" >&2
            return 1
            ;;
    esac
}

emit_describe() {
    local preferred_current="$1"
    local runtime
    local backend_state
    local fcitx_state
    local group_name
    local current_method=""
    local -a methods=()
    local method

    if ! runtime="$(load_runtime_state)"; then
        return 1
    fi

    backend_state="${runtime%% *}"
    fcitx_state="${runtime#* }"
    group_name="$(resolved_group_name)"

    if [ -n "$group_name" ]; then
        mapfile -t methods < <(load_group_methods "$group_name")
    fi

    if current_method="$(load_current_method 2>/dev/null)"; then
        :
    else
        current_method=""
    fi

    if [ -z "$current_method" ] && [ -n "$preferred_current" ]; then
        current_method="$preferred_current"
    fi

    if [ -z "$current_method" ] && [ "${#methods[@]}" -gt 0 ]; then
        current_method="${methods[0]}"
    fi

    if [ -n "$current_method" ] && ! array_contains "$current_method" "${methods[@]}"; then
        methods+=("$current_method")
    fi

    printf 'backend=%s\n' "$backend_state"
    printf 'fcitx_state=%s\n' "$fcitx_state"

    if [ -n "$group_name" ]; then
        printf 'group=%s\n' "$group_name"
    fi

    if [ -n "$current_method" ]; then
        printf 'current=%s\n' "$current_method"
    fi

    for method in "${methods[@]}"; do
        printf 'method=%s\n' "$method"
    done
}

require_running_remote() {
    if ! have_remote; then
        echo "fcitx5-remote is not installed" >&2
        return 1
    fi

    if ! remote_is_running; then
        echo "fcitx5 is not running" >&2
        return 1
    fi
}

current_or_first_method() {
    local current_method=""
    local -a methods=("$@")

    if current_method="$(load_current_method 2>/dev/null)"; then
        printf '%s\n' "$current_method"
        return 0
    fi

    if [ "${#methods[@]}" -gt 0 ]; then
        printf '%s\n' "${methods[0]}"
        return 0
    fi

    return 1
}

next_method_in_cycle() {
    local current_method="$1"
    shift || true
    local -a methods=("$@")
    local index

    if [ "${#methods[@]}" -eq 0 ]; then
        return 1
    fi

    if [ -z "$current_method" ]; then
        printf '%s\n' "${methods[0]}"
        return 0
    fi

    for index in "${!methods[@]}"; do
        if [ "${methods[$index]}" = "$current_method" ]; then
            printf '%s\n' "${methods[$(((index + 1) % ${#methods[@]}))]}"
            return 0
        fi
    done

    printf '%s\n' "${methods[0]}"
}

switch_to_method() {
    local target_method="$1"

    if [ -z "$target_method" ]; then
        echo "Missing input method name" >&2
        return 2
    fi

    if ! require_running_remote; then
        return 1
    fi

    if ! "$fcitx_remote" -s "$target_method" >/dev/null 2>&1; then
        echo "Failed to switch input method to $target_method" >&2
        return 1
    fi

    emit_describe "$target_method"
}

cycle_next_method() {
    local group_name
    local current_method
    local next_method
    local -a methods=()

    if ! require_running_remote; then
        return 1
    fi

    group_name="$(resolved_group_name)"
    if [ -n "$group_name" ]; then
        mapfile -t methods < <(load_group_methods "$group_name")
    fi

    if [ "${#methods[@]}" -eq 0 ]; then
        echo "No input methods are configured in $profile_path" >&2
        return 1
    fi

    if current_method="$(current_or_first_method "${methods[@]}")"; then
        :
    else
        current_method=""
    fi

    if ! next_method="$(next_method_in_cycle "$current_method" "${methods[@]}")"; then
        echo "Failed to resolve the next input method" >&2
        return 1
    fi

    switch_to_method "$next_method"
}

case "$action" in
    describe|status)
        emit_describe
        ;;
    current)
        if current_method="$(load_current_method 2>/dev/null)"; then
            printf '%s\n' "$current_method"
        else
            emit_describe | awk -F= '/^current=/{print $2; exit}'
        fi
        ;;
    list)
        group_name="$(resolved_group_name)"
        if [ -n "$group_name" ]; then
            load_group_methods "$group_name"
        fi
        ;;
    switch)
        switch_to_method "$1"
        ;;
    cycle-next|toggle)
        cycle_next_method
        ;;
    spanish)
        switch_to_method "$spanish_method"
        ;;
    japanese)
        switch_to_method "$japanese_method"
        ;;
    *)
        print_usage
        exit 2
        ;;
esac
