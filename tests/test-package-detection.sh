#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-package-detection.XXXXXX")
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

bin_dir=$tmp_dir/bin
mkdir -p "$bin_dir" "$tmp_dir/freebsd-bin"
cat >"$bin_dir/package-manager" <<'EOF'
#!/bin/sh
printf '%s %s\n' "$(basename -- "$0")" "$*" >>"$CALL_LOG"
EOF
chmod +x "$bin_dir/package-manager"
for manager in pacman dnf apt xbps-install pkg; do
    ln -s package-manager "$bin_dir/$manager"
done
cat >"$bin_dir/dpkg-query" <<'EOF'
#!/bin/sh
printf '%s\n' installed
EOF
cat >"$bin_dir/rpm" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$bin_dir/xbps-query" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$bin_dir/dpkg-query" "$bin_dir/rpm" "$bin_dir/xbps-query"

cat >"$bin_dir/apt-cache" <<'EOF'
#!/bin/sh
if [ "${TRITON_TEST_BACKPORTS:-}" = yes ]; then
    printf '%s\n' '500 http://deb.debian.org/debian trixie-backports/main amd64 Packages'
fi
EOF
chmod +x "$bin_dir/apt-cache"

cat >"$bin_dir/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
chmod +x "$bin_dir/sudo"

cat >"$tmp_dir/freebsd-bin/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -s) printf '%s\n' FreeBSD ;;
    -r) printf '%s\n' "${TRITON_TEST_FREEBSD_RELEASE:-15.1-RELEASE}" ;;
    *) exit 1 ;;
esac
EOF
chmod +x "$tmp_dir/freebsd-bin/uname"

call_log=$tmp_dir/package-manager.log
os_release=$tmp_dir/os-release
test_linux_distro() {
    distro_id=$1
    id_like=$2
    expected=$3
    printf 'ID=%s\nID_LIKE="%s"\n' "$distro_id" "$id_like" >"$os_release"
    : >"$call_log"
    HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
        TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages triton-test-package >/dev/null
    if ! grep -Fx "$expected" "$call_log" >/dev/null; then
        echo "Unexpected package-manager selection for $distro_id (ID_LIKE=$id_like)." >&2
        cat "$call_log" >&2
        exit 1
    fi
}

test_linux_distro cachyos arch 'pacman -S --needed git stow triton-test-package'
test_linux_distro arch '' 'pacman -S --needed git stow triton-test-package'
test_linux_distro fedora '' 'dnf install git stow triton-test-package'
test_linux_distro debian '' 'apt install git stow triton-test-package'
test_linux_distro ubuntu debian 'apt install git stow triton-test-package'
test_linux_distro void '' 'xbps-install -S git stow triton-test-package'

printf 'ID=cachyos\nID_LIKE="arch"\n' >"$os_release"
: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland custom-extra-package >/dev/null
if ! grep -Fx 'pacman -S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty networkmanager bluez bluez-utils blueman power-profiles-daemon pipewire wireplumber pipewire-pulse grim slurp wl-clipboard wtype fish starship fastfetch fcitx5 fcitx5-gtk fcitx5-qt fcitx5-anthy neovim flatpak librsvg xorg-xhost custom-extra-package' "$call_log" >/dev/null; then
    echo "Arch Hyprland profile did not resolve the expected package set." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland \
    --groups input,audio custom-extra-package >/dev/null
if ! grep -Fx 'pacman -S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty pipewire wireplumber pipewire-pulse fcitx5 fcitx5-gtk fcitx5-qt fcitx5-anthy custom-extra-package' "$call_log" >/dev/null; then
    echo "Selected Arch package groups did not resolve to base, core, and requested groups." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland \
    --groups input,not-a-group >"$tmp_dir/group-error.log" 2>&1; then
    echo "Unknown package group was accepted." >&2
    exit 1
fi
if ! grep -F "Unknown package group 'not-a-group'" "$tmp_dir/group-error.log" >/dev/null || [ -s "$call_log" ]; then
    echo "Unknown package group was not rejected before invoking the package manager." >&2
    cat "$tmp_dir/group-error.log" >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
printf '2\n' | HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland --interactive >/dev/null 2>&1
if ! grep -Fx 'pacman -S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty grim slurp wl-clipboard wtype' "$call_log" >/dev/null; then
    echo "Interactive package selection did not resolve the selected capture group." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
printf 'none\n' | HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland --interactive >/dev/null 2>&1
if ! grep -Fx 'pacman -S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty' "$call_log" >/dev/null; then
    echo "Interactive 'none' did not retain only the required base and core groups." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland \
    --groups base >/dev/null
if ! grep -Fx 'pacman -S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty' "$call_log" >/dev/null; then
    echo "Explicit base selection omitted required core dependencies." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
if printf '99\n' | HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland --interactive >"$tmp_dir/menu-error.log" 2>&1; then
    echo "Interactive package selection accepted an unavailable menu number." >&2
    exit 1
fi
if ! grep -F 'No optional package group has menu number 99' "$tmp_dir/menu-error.log" >/dev/null || [ -s "$call_log" ]; then
    echo "Invalid interactive choice was not rejected before invoking the package manager." >&2
    cat "$tmp_dir/menu-error.log" >&2
    cat "$call_log" >&2
    exit 1
fi

printf 'ID=fedora\n' >"$os_release"
: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland >"$tmp_dir/profile-error.log" 2>&1; then
    echo "Unsupported Fedora Hyprland profile was not rejected." >&2
    exit 1
fi
if ! grep -F 'do not provide a complete, matching package set' "$tmp_dir/profile-error.log" >/dev/null; then
    echo "Fedora profile refusal did not explain the missing package set." >&2
    cat "$tmp_dir/profile-error.log" >&2
    exit 1
fi
if [ -s "$call_log" ]; then
    echo "Package manager ran for an unsupported profile." >&2
    cat "$call_log" >&2
    exit 1
fi

printf 'ID=debian\nVERSION_CODENAME=bookworm\n' >"$os_release"
: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages --profile hyprland >"$tmp_dir/debian-profile-error.log" 2>&1; then
    echo "Debian Hyprland profile accepted an unsupported release." >&2
    exit 1
fi
if ! grep -F 'Debian 13 (Trixie) only' "$tmp_dir/debian-profile-error.log" >/dev/null || [ -s "$call_log" ]; then
    echo "Debian release guard did not reject an unsupported release before installing." >&2
    cat "$tmp_dir/debian-profile-error.log" >&2
    cat "$call_log" >&2
    exit 1
fi

printf 'ID=debian\nVERSION_CODENAME=trixie\n' >"$os_release"
: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release TRITON_TEST_BACKPORTS=no \
    "$repo_dir/install.sh" packages --profile hyprland >"$tmp_dir/debian-profile-error.log" 2>&1; then
    echo "Debian Hyprland profile accepted missing backports metadata." >&2
    exit 1
fi
if ! grep -F 'Enable Debian' "$tmp_dir/debian-profile-error.log" >/dev/null || [ -s "$call_log" ]; then
    echo "Debian profile did not fail safely when Trixie backports was unavailable." >&2
    cat "$tmp_dir/debian-profile-error.log" >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release TRITON_TEST_BACKPORTS=yes \
    "$repo_dir/install.sh" packages --profile hyprland custom-extra-package >/dev/null
if ! grep -Fx 'apt install -t trixie-backports git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python3 procps imagemagick playerctl brightnessctl kitty network-manager bluez blueman power-profiles-daemon pipewire wireplumber pipewire-pulse grim slurp wl-clipboard wtype fish starship fastfetch fcitx5 fcitx5-frontend-all fcitx5-anthy neovim flatpak librsvg2-bin x11-xserver-utils custom-extra-package' "$call_log" >/dev/null; then
    echo "Debian Trixie Hyprland profile did not resolve the expected package set." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$tmp_dir/freebsd-bin:$bin_dir:/usr/bin:/bin" \
    "$repo_dir/install.sh" packages triton-test-package >/dev/null
if ! grep -Fx 'pkg install git stow triton-test-package' "$call_log" >/dev/null; then
    echo "FreeBSD did not select pkg." >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$tmp_dir/freebsd-bin:$bin_dir:/usr/bin:/bin" \
    TRITON_TEST_FREEBSD_RELEASE=14.3-RELEASE \
    "$repo_dir/install.sh" packages --profile hyprland >"$tmp_dir/freebsd-profile-error.log" 2>&1; then
    echo "FreeBSD Hyprland profile accepted an unsupported release." >&2
    exit 1
fi
if ! grep -F 'supports FreeBSD 14.4, 14.5, and 15.1' "$tmp_dir/freebsd-profile-error.log" >/dev/null || [ -s "$call_log" ]; then
    echo "FreeBSD release guard did not reject an unsupported release before installing." >&2
    cat "$tmp_dir/freebsd-profile-error.log" >&2
    cat "$call_log" >&2
    exit 1
fi

: >"$call_log"
HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$tmp_dir/freebsd-bin:$bin_dir:/usr/bin:/bin" \
    "$repo_dir/install.sh" packages --profile hyprland custom-extra-package >/dev/null
if ! grep -Fx 'pkg install git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python ImageMagick7 playerctl bsdisks kitty pipewire wireplumber pipewire-spa-oss grim slurp wl-clipboard wtype fish starship fastfetch fcitx5 neovim custom-extra-package' "$call_log" >/dev/null; then
    echo "FreeBSD Hyprland profile did not resolve the expected package set." >&2
    cat "$call_log" >&2
    exit 1
fi

printf 'ID=unsupported\n' >"$os_release"
: >"$call_log"
if HOME=$tmp_dir/home CALL_LOG=$call_log PATH="$bin_dir:/usr/bin:/bin" \
    TRITON_OS_RELEASE_FILE=$os_release "$repo_dir/install.sh" packages >/dev/null 2>&1; then
    echo "Unsupported Linux distribution was not rejected." >&2
    exit 1
fi
if [ -s "$call_log" ]; then
    echo "Package manager ran for an unsupported Linux distribution." >&2
    cat "$call_log" >&2
    exit 1
fi

echo "Package-manager detection checks passed."
