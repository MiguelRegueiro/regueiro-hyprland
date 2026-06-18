#!/bin/sh

set -eu

dev="${BT_DEV:-ubt0}"
hci="${BT_HCI:-${dev}hci}"
hosts="${BT_HOSTS:-/etc/bluetooth/hosts}"
hids="${BT_HIDS:-/var/db/bthidd.hids}"

stack_ready() {
    hccontrol -n "$hci" read_node_state >/dev/null 2>&1
}

device_name() {
    mac="$1"
    awk -v target="$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')" '
        /^[[:space:]]*#/ || NF < 2 { next }
        {
            addr = tolower($1)
            if (addr == target) {
                print $2
                exit
            }
        }
    ' "$hosts" 2>/dev/null
}

known_hids() {
    [ -r "$hids" ] || return 0
    awk '
        /^[[:space:]]*#/ { next }
        {
            for (i = 1; i <= NF; ++i) {
                if ($i ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/) {
                    print $i
                    break
                }
            }
        }
    ' "$hids" 2>/dev/null
}

connected_macs() {
    stack_ready || return 0
    hccontrol -N -n "$hci" read_connection_list 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; ++i) {
                if ($i ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/)
                    print tolower($i)
            }
        }
    '
}

audio_sink_name() {
    printf '%s\n' "bt_sony"
}

start_audio_device() {
    # Bluetooth control works, but virtual_oss_bluetooth does not drain
    # sustained audio for this A2DP headset on this FreeBSD setup.
    return 0
}

connection_handle() {
    mac="$1"
    hccontrol -N -n "$hci" read_connection_list 2>/dev/null | awk -v target="$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')" '
        tolower($1) == target { print $2; exit }
    '
}

poll() {
    if stack_ready; then
        printf 'bt:yes\n'
    else
        printf 'bt:no\n'
        return 0
    fi

    connected="$(connected_macs | tr '\n' ' ')"
    seen=""

    for mac in $(known_hids); do
        lmac="$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')"
        name="$(device_name "$mac")"
        [ -n "$name" ] || name="$mac"
        case " $connected " in
            *" $lmac "*) is_connected="yes" ;;
            *) is_connected="no" ;;
        esac
        printf 'DEV|%s|%s|%s\n' "$mac" "$name" "$is_connected"
        seen="$seen $lmac"
    done

    awk '
        /^[[:space:]]*#/ || NF < 2 { next }
        {
            print $1 "|" $2
        }
    ' "$hosts" 2>/dev/null | while IFS='|' read -r mac name; do
        lmac="$(printf '%s' "$mac" | tr '[:upper:]' '[:lower:]')"
        case " $seen " in
            *" $lmac "*) continue ;;
        esac
        case " $connected " in
            *" $lmac "*) is_connected="yes" ;;
            *) is_connected="no" ;;
        esac
        printf 'DEV|%s|%s|%s\n' "$mac" "$name" "$is_connected"
    done
}

toggle() {
    if stack_ready; then
        doas service bluetooth stop "$dev"
    else
        doas service bluetooth start "$dev"
    fi
}

connect_device() {
    mac="${1:-}"
    [ -n "$mac" ] || {
        echo "No Bluetooth address specified" >&2
        exit 1
    }
    if [ -n "$(connection_handle "$mac")" ]; then
        start_audio_device "$mac"
        echo "Already connected"
        return 0
    fi
    doas hccontrol -n "$hci" create_connection "$mac" 0xcc18 2 0 0 1
    start_audio_device "$mac"
    echo "Connection successful"
}

disconnect_device() {
    mac="${1:-}"
    [ -n "$mac" ] || {
        echo "No Bluetooth address specified" >&2
        exit 1
    }
    handle="$(connection_handle "$mac")"
    [ -n "$handle" ] || {
        echo "Device is not connected" >&2
        exit 1
    }
    doas hccontrol -n "$hci" disconnect "$handle" 19
    echo "Disconnect successful"
}

forget_device() {
    mac="${1:-}"
    [ -n "$mac" ] || {
        echo "No Bluetooth address specified" >&2
        exit 1
    }

    if [ -n "$(connection_handle "$mac")" ]; then
        disconnect_device "$mac" >/dev/null 2>&1 || true
    fi

    doas sh -c '
        mac="$1"
        lower="$(printf "%s" "$mac" | tr "[:upper:]" "[:lower:]")"

        if [ -f /etc/bluetooth/hosts ]; then
            awk -v target="$lower" "
                /^[[:space:]]*#/ { print; next }
                NF >= 1 && tolower(\$1) == target { next }
                { print }
            " /etc/bluetooth/hosts > /tmp/qs-bt-hosts &&
            install -m 0644 -o root -g wheel /tmp/qs-bt-hosts /etc/bluetooth/hosts
        fi

        if [ -f /etc/bluetooth/hcsecd.conf ]; then
            awk -v target="$lower" "
                BEGIN { in_block = 0; block = \"\"; block_match = 0 }
                /^[[:space:]]*device[[:space:]]*\\{/ {
                    in_block = 1
                    block = \$0 ORS
                    block_match = 0
                    next
                }
                in_block {
                    block = block \$0 ORS
                    if (tolower(\$0) ~ \"bdaddr[[:space:]]+\" target \"[[:space:]]*;\")
                        block_match = 1
                    if (\$0 ~ /^[[:space:]]*\\}/) {
                        if (!block_match)
                            printf \"%s\", block
                        in_block = 0
                        block = \"\"
                        block_match = 0
                    }
                    next
                }
                { print }
            " /etc/bluetooth/hcsecd.conf > /tmp/qs-bt-hcsecd.conf &&
            install -m 0600 -o root -g wheel /tmp/qs-bt-hcsecd.conf /etc/bluetooth/hcsecd.conf
        fi

        service hcsecd restart >/dev/null 2>&1 || true
    ' sh "$mac"

    echo "Forget successful"
}

case "${1:-poll}" in
    poll)
        poll
        ;;
    toggle)
        toggle
        ;;
    connect)
        connect_device "${2:-}"
        ;;
    disconnect)
        disconnect_device "${2:-}"
        ;;
    forget)
        forget_device "${2:-}"
        ;;
    settings)
        title="Bluetooth Settings"
        cmd="doas bluetooth-config scan -n $dev; printf '\\nPress Enter to close...'; read _"
        if command -v kitty >/dev/null 2>&1; then
            exec kitty --title "$title" sh -lc "$cmd"
        fi
        if command -v xterm >/dev/null 2>&1; then
            exec xterm -T "$title" -e sh -lc "$cmd"
        fi
        echo "No terminal emulator is available for Bluetooth settings" >&2
        exit 1
        ;;
    *)
        echo "usage: $0 poll|toggle|connect BD_ADDR|disconnect BD_ADDR|forget BD_ADDR|settings" >&2
        exit 2
        ;;
esac
