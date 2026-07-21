#!/bin/sh

set -eu

state_file="${XDG_RUNTIME_DIR:-/tmp}/quickshell-power-profile"

usage() {
    echo "usage: $0 get|set power-saver|balanced|performance" >&2
    exit 2
}

flags_for_mode() {
    case "${1:-}" in
        power-saver)
            printf '%s\n' "-a minimum -b minimum -n minimum"
            ;;
        balanced)
            printf '%s\n' "-a hiadaptive -b adaptive -n adaptive"
            ;;
        performance)
            printf '%s\n' "-a maximum -b maximum -n maximum"
            ;;
        *)
            usage
            ;;
    esac
}

epp_for_mode() {
    case "${1:-}" in
        power-saver)
            printf '%s\n' "100"
            ;;
        balanced)
            printf '%s\n' "50"
            ;;
        performance)
            printf '%s\n' "0"
            ;;
        *)
            usage
            ;;
    esac
}

mode_from_flags() {
    flags=" ${1:-} "

    case "$flags" in
        *" minimum "*|*" min "*)
            printf '%s\n' "power-saver"
            return 0
            ;;
    esac

    case "$flags" in
        *" maximum "*|*" max "*)
            printf '%s\n' "performance"
            return 0
            ;;
    esac

    printf '%s\n' "balanced"
}

current_flags() {
    flags="$(sysrc -n powerd_flags 2>/dev/null || true)"
    if [ -n "$flags" ]; then
        printf '%s\n' "$flags"
        return 0
    fi

    pid=""
    if [ -r /var/run/powerd.pid ]; then
        pid="$(cat /var/run/powerd.pid 2>/dev/null || true)"
    fi

    if [ -n "$pid" ]; then
        ps -p "$pid" -o command= 2>/dev/null | sed 's|^/usr/sbin/powerd[[:space:]]*||'
        return 0
    fi

    printf '%s\n' ""
}

get_mode() {
    if [ -r "$state_file" ]; then
        mode="$(cat "$state_file" 2>/dev/null || true)"
        case "$mode" in
            power-saver|balanced|performance)
                printf '%s\n' "$mode"
                return 0
                ;;
        esac
    fi

    mode_from_flags "$(current_flags)"
}

set_mode() {
    mode="${1:-}"
    flags="$(flags_for_mode "$mode")"
    epp="$(epp_for_mode "$mode")"

    # Live media can have a read-only /etc, so do not rely on sysrc here.
    # Restart powerd directly with the requested transient flags instead.
    # shellcheck disable=SC2086
    doas sh -c '
        epp="$1"
        shift

        service powerd onestop >/dev/null 2>&1 || true
        /usr/sbin/powerd "$@" >/dev/null 2>&1

        ncpu="$(sysctl -n hw.ncpu 2>/dev/null || printf 0)"
        cpu=0
        while [ "$cpu" -lt "$ncpu" ]; do
            sysctl "dev.hwpstate_intel.${cpu}.epp=${epp}" >/dev/null 2>&1 || true
            cpu=$((cpu + 1))
        done
    ' sh "$epp" $flags
    printf '%s\n' "$mode" > "$state_file"

    printf '%s\n' "$mode"
}

case "${1:-}" in
    get)
        get_mode
        ;;
    set)
        shift
        set_mode "${1:-}"
        ;;
    *)
        usage
        ;;
esac
