#!/bin/sh

set -eu

iface="${WIFI_IFACE:-}"
if [ -z "$iface" ]; then
    iface="$(ifconfig -l | tr ' ' '\n' | awk '/^wlan[0-9]+$/ { print; exit }')"
fi
if [ -z "$iface" ]; then
    iface="wlan0"
fi

wpa_conf="${WPA_SUPPLICANT_CONF:-${XDG_RUNTIME_DIR:-/tmp}/triton-wpa_supplicant.conf}"

wifi_parent() {
    sysctl -n net.wlan.devices 2>/dev/null | awk '{ print $1 }'
}

ensure_iface() {
    parent="$(wifi_parent)"
    if ifconfig "$iface" >/dev/null 2>&1; then
        return 0
    fi

    [ -n "$parent" ] || return 1
    doas ifconfig "$iface" create wlandev "$parent" >/dev/null 2>&1 || true
    ifconfig "$iface" >/dev/null 2>&1
}

current_ssid() {
    ifconfig_out="$(ifconfig "$iface" 2>/dev/null || true)"
    printf '%s\n' "$ifconfig_out" | grep -q "status: associated" || return 0
    printf '%s\n' "$ifconfig_out" | sed -n \
        -e 's/.*ssid "\([^"]*\)".*/\1/p' \
        -e 's/.*ssid \([^[:space:]]*\) channel .*/\1/p' | head -n 1
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

start_wifi() {
    ensure_iface || return 1
    doas ifconfig "$iface" country ES regdomain ETSI >/dev/null 2>&1 || true
    doas ifconfig "$iface" up
    if [ -s "$wpa_conf" ]; then
        doas pkill -f "wpa_supplicant.*-i[[:space:]]*$iface" >/dev/null 2>&1 || true
        doas wpa_supplicant -B -i "$iface" -c "$wpa_conf"
        doas dhclient "$iface" >/dev/null 2>&1 || true
    fi
}

toggle_wifi() {
    if [ "$(wifi_state)" = "enabled" ]; then
        # On the HP/RTL8822CE FreeBSD live image, cycling rtw88 with ifconfig
        # down/up can panic in the LinuxKPI net80211 receive path. Keep the
        # interface under rc.conf/netif control like the installed system.
        printf '%s\n' "wifi:enabled"
    else
        # Same reason: do not manually raise a downed rtw88 interface from QS.
        # The live image brings wlan0 up through rc.conf at boot.
        echo "Wi-Fi is managed by FreeBSD rc.conf on this live image; reboot to re-enable wlan0" >&2
        return 1
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
            echo "$iface does not exist; reboot or let FreeBSD rc.conf create it" >&2
            exit 1
        fi
        if ! ifconfig "$iface" 2>/dev/null | sed -n '1p' | grep -q "<.*UP"; then
            echo "$iface is down; reboot to let FreeBSD rc.conf bring Wi-Fi up safely" >&2
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
        doas "$0" root-update connect "${2:-}" "${3:-}"
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
