#!/bin/sh

set -eu

iface="${WIFI_IFACE:-}"
if [ -z "$iface" ]; then
    iface="$(ifconfig -l | tr ' ' '\n' | awk '/^wlan[0-9]+$/ { print; exit }')"
fi
if [ -z "$iface" ]; then
    iface="wlan0"
fi

wpa_conf="${WPA_SUPPLICANT_CONF:-/etc/wpa_supplicant.conf}"

current_ssid() {
    ifconfig "$iface" 2>/dev/null | sed -n 's/.*ssid \(.*\) channel .*/\1/p' | head -n 1
}

wifi_state() {
    if ifconfig "$iface" 2>/dev/null | grep -q "status: associated"; then
        printf '%s\n' "enabled"
        return
    fi

    if ifconfig "$iface" 2>/dev/null | sed -n '1p' | grep -q "<.*UP"; then
        printf '%s\n' "enabled"
    else
        printf '%s\n' "disabled"
    fi
}

list_profiles() {
    doas cat "$wpa_conf" 2>/dev/null | awk '
        /^[[:space:]]*ssid="/ {
            line = $0
            sub(/^[[:space:]]*ssid="/, "", line)
            sub(/"[[:space:]]*$/, "", line)
            gsub(/\\"/, "\"", line)
            print line ":wifi"
        }
    '
}

scan_networks() {
    connected="$(current_ssid)"
    printf 'wifi:%s\n' "$(wifi_state)"
    printf 'ssid:%s\n' "$connected"

    ifconfig "$iface" list scan 2>/dev/null | awk -v active_ssid="$connected" '
        NR == 1 { next }
        {
            ssid = substr($0, 1, 32)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", ssid)
            if (ssid == "")
                next

            rest = substr($0, 33)
            gsub(/^[[:space:]]+/, "", rest)
            split(rest, cols, /[[:space:]]+/)
            split(cols[4], sn, ":")
            dbm = sn[1] + 0
            signal = dbm + 100
            if (signal < 0)
                signal = 0
            if (signal > 100)
                signal = 100

            security = ""
            if ($0 ~ /(^|[[:space:]])(RSN|WPA|WEP)([[:space:]]|$)/)
                security = "WPA"

            in_use = ssid == active_ssid ? "*" : ""
            gsub(/\\/, "\\\\", ssid)
            gsub(/:/, "\\:", ssid)

            print "NET:IN-USE:" in_use
            print "NET:SSID:" ssid
            print "NET:SECURITY:" security
            print "NET:SIGNAL:" signal
        }
    '
}

network_state() {
    if ifconfig ue0 2>/dev/null | grep -q "status: active"; then
        printf '%s\n' "eth"
    elif [ "$(wifi_state)" = "enabled" ] && [ -n "$(current_ssid)" ]; then
        printf '%s\n' "wifi_up"
    elif [ "$(wifi_state)" = "enabled" ]; then
        printf '%s\n' "wifi_off"
    else
        printf '%s\n' "off"
    fi
}

toggle_wifi() {
    if [ "$(wifi_state)" = "enabled" ]; then
        doas ifconfig "$iface" down
    else
        doas service netif restart "$iface"
    fi
}

root_update_wifi() {
    action="$1"
    ssid="${2:-}"
    psk="${3:-}"
    tmp="${wpa_conf}.qs.$$"

    [ "$(id -u)" -eq 0 ] || {
        echo "This action must run as root" >&2
        exit 1
    }

    [ -n "$ssid" ] || {
        echo "No SSID specified" >&2
        exit 1
    }

    awk -v target="$ssid" '
        BEGIN { depth = 0; block = ""; block_ssid = "" }
        /^[[:space:]]*network=\{/ {
            depth = 1
            block = $0 ORS
            block_ssid = ""
            next
        }
        depth > 0 {
            block = block $0 ORS
            if ($0 ~ /^[[:space:]]*ssid="/) {
                block_ssid = $0
                sub(/^[[:space:]]*ssid="/, "", block_ssid)
                sub(/"[[:space:]]*$/, "", block_ssid)
                gsub(/\\"/, "\"", block_ssid)
            }
            if ($0 ~ /^[[:space:]]*\}/) {
                if (block_ssid != target)
                    printf "%s", block
                depth = 0
                block = ""
                block_ssid = ""
            }
            next
        }
        { print }
    ' "$wpa_conf" > "$tmp"

    if [ "$action" = "connect" ]; then
        esc_ssid="$(printf '%s' "$ssid" | sed 's/\\/\\\\/g; s/"/\\"/g')"
        {
            printf 'network={\n'
            printf '\tssid="%s"\n' "$esc_ssid"
            if [ -n "$psk" ]; then
                esc_psk="$(printf '%s' "$psk" | sed 's/\\/\\\\/g; s/"/\\"/g')"
                printf '\tpsk="%s"\n' "$esc_psk"
            else
                printf '\tkey_mgmt=NONE\n'
            fi
            printf '}\n'
        } >> "$tmp"
    elif [ "$action" != "forget" ]; then
        rm -f "$tmp"
        echo "Unknown action: $action" >&2
        exit 1
    fi

    chmod 600 "$tmp"
    chown root:wheel "$tmp"
    mv "$tmp" "$wpa_conf"
    service netif restart "$iface"
}

case "${1:-scan}" in
    scan)
        scan_networks
        ;;
    profiles)
        list_profiles
        ;;
    connect)
        ssid="${2:-}"
        psk="${3:-}"
        if [ -n "$psk" ]; then
            doas "$0" root-update connect "$ssid" "$psk"
        else
            doas ifconfig "$iface" ssid "$ssid"
            doas service netif restart "$iface"
        fi
        ;;
    forget)
        doas "$0" root-update forget "${2:-}"
        ;;
    toggle)
        toggle_wifi
        ;;
    network-state)
        network_state
        ;;
    root-update)
        shift
        root_update_wifi "$@"
        ;;
    *)
        echo "usage: $0 scan|profiles|connect SSID [PASSWORD]|forget SSID|toggle|network-state" >&2
        exit 2
        ;;
esac
