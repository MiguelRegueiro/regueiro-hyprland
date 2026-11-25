#!/bin/sh

set -eu

iface="${WIFI_IFACE:-}"
if [ -z "$iface" ]; then
    iface="$(ifconfig -l 2>/dev/null | tr ' ' '\n' | awk '/^wlan[0-9]+$/ { print; exit }' || true)"
fi
if [ -z "$iface" ]; then
    iface="wlan0"
fi

wpa_conf="${WPA_SUPPLICANT_CONF:-${XDG_RUNTIME_DIR:-/tmp}/triton-wpa_supplicant.conf}"
disabled_marker="${XDG_RUNTIME_DIR:-/tmp}/triton-wifi-disabled.${iface}"

wifi_parent() {
    sysctl -n net.wlan.devices 2>/dev/null | awk '{ print $1 }'
}

iface_is_up() {
    printf '%s\n' "$1" | sed -n '1p' | grep -Eq '<([^>]*,)?UP(,|>)'
}

iface_has_ipv4() {
    printf '%s\n' "$1" | grep -Eq '^[[:space:]]*inet[[:space:]]'
}

ethernet_is_connected() {
    iface_is_up "$1" &&
        printf '%s\n' "$1" | grep -q "status: active" &&
        iface_has_ipv4 "$1"
}

wifi_disabled() {
    [ -e "$disabled_marker" ]
}

ethernet_iface() {
    if [ -n "${ETH_IFACE:-}" ]; then
        if ifconfig "$ETH_IFACE" >/dev/null 2>&1; then
            printf '%s\n' "$ETH_IFACE"
            return
        fi
    fi

    wifi_devices="$(wifi_parent)"
    ifconfig -l 2>/dev/null | tr ' ' '\n' | awk -v wifi_devices=" $wifi_devices " '
        /^$/ { next }
        index(wifi_devices, " " $0 " ") { next }
        /^(lo[0-9]*|wlan[0-9]*|bridge[0-9]*|tap[0-9]*|tun[0-9]*|vnet[0-9]*|vmnet[0-9]*|epair[0-9]+[ab]?|pflog[0-9]*|pfsync[0-9]*|wg[0-9]*|tailscale[0-9]*|docker[0-9]*|br[0-9]*|virbr[0-9]*|enc[0-9]*|gif[0-9]*|gre[0-9]*|stf[0-9]*)$/ { next }
        { print; exit }
    '
}

ethernet_state() {
    eth_iface="$(ethernet_iface)"
    if [ -z "$eth_iface" ]; then
        printf '%s\n' "unavailable"
        return
    fi

    eth_ifconfig="$(ifconfig "$eth_iface" 2>/dev/null || true)"
    if ethernet_is_connected "$eth_ifconfig"; then
        printf '%s\n' "connected"
    else
        printf '%s\n' "available"
    fi
}

ensure_iface() {
    if ifconfig "$iface" >/dev/null 2>&1; then
        return 0
    fi

    echo "$iface does not exist; reboot to let FreeBSD rc.conf create it safely" >&2
    return 1
}

current_ssid() {
    wifi_disabled && return 0

    ifconfig_out="$(ifconfig "$iface" 2>/dev/null || true)"
    printf '%s\n' "$ifconfig_out" | grep -q "status: associated" || return 0
    printf '%s\n' "$ifconfig_out" | sed -n \
        -e 's/.*ssid "\([^"]*\)".*/\1/p' \
        -e 's/.*ssid \([^[:space:]]*\) channel .*/\1/p' | head -n 1
}

wifi_state() {
    if wifi_disabled; then
        printf '%s\n' "disabled"
        return
    fi

    if ifconfig "$iface" 2>/dev/null | grep -q "status: associated"; then
        printf '%s\n' "enabled"
        return
    fi

    if iface_is_up "$(ifconfig "$iface" 2>/dev/null || true)"; then
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
    if wifi_disabled; then
        printf '%s\n' "wifi:disabled"
        printf '%s\n' "ssid:"
        return
    fi

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
    if [ "$(ethernet_state)" = "connected" ]; then
        printf '%s\n' "eth"
    elif [ "$(wifi_state)" = "enabled" ] && [ -n "$(current_ssid)" ]; then
        printf '%s\n' "wifi_up"
    elif [ "$(wifi_state)" = "enabled" ]; then
        printf '%s\n' "wifi_off"
    else
        printf '%s\n' "off"
    fi
}

status() {
    eth_iface="$(ethernet_iface)"
    eth_state="unavailable"
    if [ -n "$eth_iface" ]; then
        eth_ifconfig="$(ifconfig "$eth_iface" 2>/dev/null || true)"
        if ethernet_is_connected "$eth_ifconfig"; then
            eth_state="connected"
        else
            eth_state="available"
        fi
    fi

    wifi_ifconfig="$(ifconfig "$iface" 2>/dev/null || true)"
    wifi_state_value="disabled"
    wifi_ssid=""
    if wifi_disabled; then
        wifi_state_value="disabled"
    elif printf '%s\n' "$wifi_ifconfig" | grep -q "status: associated"; then
        wifi_state_value="enabled"
        wifi_ssid="$(printf '%s\n' "$wifi_ifconfig" | sed -n \
            -e 's/.*ssid "\([^"]*\)".*/\1/p' \
            -e 's/.*ssid \([^[:space:]]*\) channel .*/\1/p' | head -n 1)"
    elif iface_is_up "$wifi_ifconfig"; then
        wifi_state_value="enabled"
    fi

    if [ "$eth_state" = "connected" ]; then
        printf '%s\n' "eth"
    elif [ "$wifi_state_value" = "enabled" ] && [ -n "$wifi_ssid" ]; then
        printf '%s\n' "wifi_up"
    elif [ "$wifi_state_value" = "enabled" ]; then
        printf '%s\n' "wifi_off"
    else
        printf '%s\n' "off"
    fi
    printf '%s\n' "$eth_state"
}

start_wifi() {
    rm -f "$disabled_marker"
    ensure_iface || return 1

    doas service netif start "$iface" || true
    if ! iface_is_up "$(ifconfig "$iface" 2>/dev/null || true)"; then
        echo "FreeBSD netif did not bring $iface up; reboot instead of cycling rtw88 manually" >&2
        return 1
    fi

    if [ -s "$wpa_conf" ]; then
        doas pkill -f "wpa_supplicant.*-i[[:space:]]*$iface" >/dev/null 2>&1 || true
        doas wpa_supplicant -B -i "$iface" -c "$wpa_conf"
        doas dhclient "$iface" >/dev/null 2>&1 || true
    fi
}

stop_wifi() {
    mkdir -p "$(dirname "$disabled_marker")"
    touch "$disabled_marker"

    default_gateway="$(netstat -rn -f inet 2>/dev/null | awk -v iface="$iface" '$1 == "default" && $NF == iface { print $2; exit }')"

    doas service wpa_supplicant stop "$iface" >/dev/null 2>&1 || \
        doas pkill -f "wpa_supplicant.*-i[[:space:]]*$iface([[:space:]]|$)" >/dev/null 2>&1 || true
    doas service dhclient stop "$iface" >/dev/null 2>&1 || \
        doas pkill -f "dhclient:.*$iface" >/dev/null 2>&1 || true

    inet_addr="$(ifconfig "$iface" 2>/dev/null | awk '/^[[:space:]]*inet / { print $2; exit }')"
    if [ -n "$inet_addr" ]; then
        doas ifconfig "$iface" inet "$inet_addr" delete >/dev/null 2>&1 || true
    fi

    if netstat -rn -f inet 2>/dev/null | awk -v iface="$iface" '$1 == "default" && $NF == iface { found = 1 } END { exit found ? 0 : 1 }'; then
        doas route delete default >/dev/null 2>&1 || true
    fi

    eth_iface="$(ethernet_iface)"
    if [ -n "$default_gateway" ] && [ -n "$eth_iface" ] && [ "$(ethernet_state)" = "connected" ]; then
        doas route add default "$default_gateway" >/dev/null 2>&1 || true
    fi
}

toggle_wifi() {
    if wifi_disabled || [ "$(wifi_state)" = "disabled" ]; then
        start_wifi
    else
        stop_wifi
    fi
}

toggle_ethernet() {
    eth_iface="$(ethernet_iface)"
    if [ -z "$eth_iface" ]; then
        echo "No Ethernet interface found" >&2
        return 1
    fi

    eth_ifconfig="$(ifconfig "$eth_iface" 2>/dev/null || true)"
    if ethernet_is_connected "$eth_ifconfig"; then
        doas service dhclient stop "$eth_iface" >/dev/null 2>&1 || \
            doas pkill -f "dhclient:.*$eth_iface" >/dev/null 2>&1 || true
        inet_addr="$(printf '%s\n' "$eth_ifconfig" | awk '/^[[:space:]]*inet / { print $2; exit }')"
        if [ -n "$inet_addr" ]; then
            doas ifconfig "$eth_iface" inet "$inet_addr" delete
        fi
        doas ifconfig "$eth_iface" down
    else
        doas ifconfig "$eth_iface" up
        doas dhclient "$eth_iface"
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

    mkdir -p "$(dirname "$wpa_conf")"
    touch "$wpa_conf"
    chmod 600 "$wpa_conf"
    chown root:wheel "$wpa_conf" 2>/dev/null || true

    profile_exists=no
    awk -v target="$ssid" '
        /^[[:space:]]*ssid="/ {
            line = $0
            sub(/^[[:space:]]*ssid="/, "", line)
            sub(/"[[:space:]]*$/, "", line)
            gsub(/\\"/, "\"", line)
            if (line == target)
                found = 1
        }
        END { exit found ? 0 : 1 }
    ' "$wpa_conf" && profile_exists=yes || profile_exists=no

    if [ "$action" = "connect" ] && [ -z "$psk" ] && [ "$profile_exists" = "yes" ]; then
        cp "$wpa_conf" "$tmp"
    else
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
    fi

    chmod 600 "$tmp"
    chown root:wheel "$tmp" 2>/dev/null || true
    mv "$tmp" "$wpa_conf"

    if [ "$action" = "connect" ]; then
        if ! ifconfig "$iface" >/dev/null 2>&1; then
            echo "$iface does not exist; reboot to let FreeBSD rc.conf create it safely" >&2
            exit 1
        fi
        if ! iface_is_up "$(ifconfig "$iface" 2>/dev/null || true)"; then
            echo "$iface is down; use the Wi-Fi toggle once or reboot instead of cycling rtw88 manually" >&2
            exit 1
        fi
        pkill -f "wpa_supplicant.*-i[[:space:]]*$iface" >/dev/null 2>&1 || true
        wpa_supplicant -B -i "$iface" -c "$wpa_conf"
        dhclient "$iface" >/dev/null 2>&1 || true
    fi
}

case "${1:-scan}" in
    scan)
        scan_networks
        ;;
    profiles)
        list_profiles
        ;;
    connect)
        rm -f "$disabled_marker"
        doas "$0" root-update connect "${2:-}" "${3:-}"
        ;;
    forget)
        doas "$0" root-update forget "${2:-}"
        ;;
    toggle)
        toggle_wifi
        ;;
    toggle-ethernet)
        toggle_ethernet
        ;;
    network-state)
        network_state
        ;;
    ethernet-state)
        ethernet_state
        ;;
    status)
        status
        ;;
    root-update)
        shift
        root_update_wifi "$@"
        ;;
    *)
        echo "usage: $0 scan|profiles|connect SSID [PASSWORD]|forget SSID|toggle|toggle-ethernet|network-state|ethernet-state|status" >&2
        exit 2
        ;;
esac
