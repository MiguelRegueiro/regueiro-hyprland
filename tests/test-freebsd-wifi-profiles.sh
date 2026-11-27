#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper=$repo_dir/desktop/platforms/freebsd/libexec/triton-privileged
profile_awk=$repo_dir/desktop/platforms/freebsd/libexec/triton-wifi-profile.awk
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-wifi-profiles.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

psk='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
extracted=$(printf 'network={\n\t#psk="secret-is-commented"\n\tpsk=%s\n}\n' "$psk" |
    awk -v mode=psk -f "$profile_awk")
[ "$extracted" = "$psk" ] || {
    echo "WPA key extraction failed for standard wpa_passphrase output." >&2
    exit 1
}

ssid='Cafe'
marker="# triton-ssid=$(printf '%s' "$ssid" | od -An -tx1 | tr -d ' \n')"
other_marker='# triton-ssid=4e6574776f726b'
profile=$tmp_dir/wpa_supplicant.conf

write_cafe() {
    key=$1
    {
        printf 'network={\n\t%s\n\tssid="Cafe"\n\tpsk=%s\n}\n' "$marker" "$key"
    } >>"$profile"
}

# Creating a saved profile stores one marker-owned block.
: >"$profile"
write_cafe "$psk"
[ "$(grep -c 'ssid="Cafe"' "$profile")" -eq 1 ]

# Reconnecting with a new passphrase replaces the saved block rather than
# appending a duplicate. The marker's leading tab must not prevent a match.
replacement='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
awk -v target="$marker" -f "$profile_awk" "$profile" >"$tmp_dir/filtered"
mv "$tmp_dir/filtered" "$profile"
write_cafe "$replacement"
[ "$(grep -c 'ssid="Cafe"' "$profile")" -eq 1 ]
grep -F "psk=$replacement" "$profile" >/dev/null
if grep -F "psk=$psk" "$profile" >/dev/null; then
    echo "Reconnect retained the old saved Wi-Fi key." >&2
    exit 1
fi

# A separate network survives replacing and forgetting this profile.
printf 'network={\n\t%s\n\tssid="Network"\n\tkey_mgmt=NONE\n}\n' \
    "$other_marker" >>"$profile"
awk -v target="$marker" -f "$profile_awk" "$profile" >"$tmp_dir/filtered"
mv "$tmp_dir/filtered" "$profile"
[ "$(grep -c 'ssid="Network"' "$profile")" -eq 1 ]
if grep -F 'ssid="Cafe"' "$profile" >/dev/null; then
    echo "Forgetting a network retained its saved profile." >&2
    exit 1
fi

# UTF-8 SSIDs are printable data; control bytes remain rejected.
if printf 'Café' | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo "The C-locale SSID control check rejected a UTF-8 SSID." >&2
    exit 1
fi
if ! printf '\001' | LC_ALL=C grep -q '[[:cntrl:]]'; then
    echo "The C-locale SSID control check accepted a control byte." >&2
    exit 1
fi
unicode_ssid='Café'
unicode_marker="# triton-ssid=$(printf '%s' "$unicode_ssid" | od -An -tx1 | tr -d ' \n')"
printf 'network={\n\t%s\n\tssid="%s"\n\tkey_mgmt=NONE\n}\n' \
    "$unicode_marker" "$unicode_ssid" >"$tmp_dir/unicode.conf"
awk -v target="$unicode_marker" -f "$profile_awk" "$tmp_dir/unicode.conf" >"$tmp_dir/unicode-filtered"
[ ! -s "$tmp_dir/unicode-filtered" ] || {
    echo "UTF-8 SSID marker was not matched as its original byte sequence." >&2
    exit 1
}

sh -n "$helper"
grep -F 'lockf -k -p -t 15 "$wifi_lock_file"' "$helper" >/dev/null
grep -F 'require_wifi_lock' "$helper" >/dev/null
if grep -F 'umount -f' "$helper" >/dev/null; then
    echo "Privileged unmount still forces an unmount." >&2
    exit 1
fi
grep -F 'DOAS_USER' "$helper" >/dev/null

# Execute the actual privileged helper against an isolated config directory and
# fake FreeBSD commands. This exercises the lock/re-exec path as well as real
# profile creation, reconnect, replacement, listing, and forgetting.
mock_bin=$tmp_dir/mock-bin
mock_wifi_dir=$tmp_dir/etc/triton-desktop
mock_helper=$tmp_dir/triton-privileged
mkdir -p "$mock_bin" "$mock_wifi_dir"
cat >"$mock_bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] || exit 2
printf '0\n'
EOF
cat >"$mock_bin/stat" <<'EOF'
#!/bin/sh
case "${2:-}" in %u) printf '0\n' ;; %Lp) printf '755\n' ;; *) exit 2 ;; esac
EOF
cat >"$mock_bin/chown" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$mock_bin/lockf" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -k|-p) shift ;;
        -t) shift 2 ;;
        *) break ;;
    esac
done
lock_file=$1
shift
printf '%s\n' "$$" >"$lock_file"
exec "$@"
EOF
cat >"$mock_bin/wpa_passphrase" <<'EOF'
#!/bin/sh
IFS= read -r passphrase || true
case "$passphrase" in
    oldsecret) key=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
    newsecret) key=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ;;
    *) exit 1 ;;
esac
printf '\t#psk="%s"\n\tpsk=%s\n' "$passphrase" "$key"
EOF
for command in ifconfig pkill wpa_supplicant dhclient; do
    cat >"$mock_bin/$command" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -*) exit 0 ;;
esac
printf '<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST>\n'
EOF
done
chmod +x "$mock_bin"/*
sed \
    -e "s|^PATH=.*|PATH=$mock_bin:/usr/bin:/bin|" \
    -e "s|^wifi_conf=.*|wifi_conf=$mock_wifi_dir/wpa_supplicant.conf|" \
    -e "s|^wifi_dir=.*|wifi_dir=$mock_wifi_dir|" \
    -e "s|^wifi_lock_file=.*|wifi_lock_file=$tmp_dir/wifi.lock|" \
    -e "s|/usr/bin/lockf|$mock_bin/lockf|g" \
    -e "s|/usr/local/libexec/triton-wifi-profile.awk|$profile_awk|g" \
    "$helper" >"$mock_helper"
chmod +x "$mock_helper"

unicode_profile_ssid='Café'
if "$mock_helper" wifi-connect-locked wlan0 "$unicode_profile_ssid" \
    </dev/null >"$tmp_dir/unlocked-action.log" 2>&1; then
    echo "Privileged internal Wi-Fi action bypassed the serialization lock." >&2
    exit 1
fi
printf 'oldsecret\n' | "$mock_helper" wifi connect wlan0 "$unicode_profile_ssid"
wifi_config=$mock_wifi_dir/wpa_supplicant.conf
[ "$(grep -c 'ssid="Café"' "$wifi_config")" -eq 1 ]
if mode=$(stat -c %a "$wifi_config" 2>/dev/null); then
    :
else
    mode=$(stat -f %Lp "$wifi_config")
fi
[ "$mode" = 600 ] || [ "$mode" = 0600 ]
if grep -F 'oldsecret' "$wifi_config" >/dev/null; then
    echo "Saved Wi-Fi configuration exposed the passphrase." >&2
    exit 1
fi

# Reconnecting without entering a new password reuses the correctly matched
# saved profile instead of appending another block.
"$mock_helper" wifi connect wlan0 "$unicode_profile_ssid" </dev/null
[ "$(grep -c 'ssid="Café"' "$wifi_config")" -eq 1 ]

# Supplying a replacement passphrase updates the existing marker-owned block.
printf 'newsecret\n' | "$mock_helper" wifi connect wlan0 "$unicode_profile_ssid"
[ "$(grep -c 'ssid="Café"' "$wifi_config")" -eq 1 ]
grep -F 'psk=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' "$wifi_config" >/dev/null
if grep -F 'psk=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$wifi_config" >/dev/null; then
    echo "Replacing a Wi-Fi key retained the previous key." >&2
    exit 1
fi
"$mock_helper" wifi profiles | grep -Fx 'Café:wifi' >/dev/null

"$mock_helper" wifi forget wlan0 "$unicode_profile_ssid"
if [ -s "$wifi_config" ]; then
    echo "Forgetting the saved network left its profile behind." >&2
    cat "$wifi_config" >&2
    exit 1
fi

echo "FreeBSD Wi-Fi key parsing and mocked privileged create/reconnect/replace/forget actions passed; native radio behavior still needs FreeBSD validation."
