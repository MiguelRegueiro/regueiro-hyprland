#!/bin/sh

set -eu

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
    mode_from_flags "$(current_flags)"
}

set_mode() {
    mode="${1:-}"
    flags="$(flags_for_mode "$mode")"

    doas sysrc powerd_enable=YES >/dev/null
    doas sysrc "powerd_flags=$flags" >/dev/null

    if service powerd onestatus >/dev/null 2>&1; then
        doas service powerd restart >/dev/null
    else
        doas service powerd start >/dev/null
    fi

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
