#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-installer-test.XXXXXX")
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required for installer tests." >&2
    exit 77
fi

fresh_home=$tmp_dir/fresh-home
mkdir -p "$fresh_home"
mkdir -p "$fresh_home/.config/quickshell"
printf '%s\n' 'local notification settings' >"$fresh_home/.config/quickshell/notification-times.ini"
mkdir -p "$fresh_home/.config/fcitx5/conf" \
    "$fresh_home/.local/share/applications" \
    "$fresh_home/.local/share/flatpak/overrides"
printf '%s\n' 'local input layout' >"$fresh_home/.config/fcitx5/conf/cached_layouts"
printf '%s\n' 'local elio launcher' >"$fresh_home/.local/share/applications/elio.desktop"
printf '%s\n' 'local browser override' >"$fresh_home/.local/share/flatpak/overrides/app.zen_browser.zen"
mkdir -p "$fresh_home/.config/user-app" "$fresh_home/.local/share/user-app" "$fresh_home/.local/bin"
printf '%s\n' 'user-owned settings' >"$fresh_home/.config/user-app/settings.ini"
printf '%s\n' 'user-owned target' >"$fresh_home/.local/share/user-app/data"
ln -s "$fresh_home/.local/share/user-app/data" "$fresh_home/.local/bin/user-app-data"
HOME=$fresh_home "$repo_dir/install.sh" >/dev/null
HOME=$fresh_home "$repo_dir/install.sh" >/dev/null

for relative in \
    .config/hypr/scripts/run-session-command \
    .config/hypr/scripts/start-session-quickshell \
    .config/hypr/scripts/start-session-services \
    .config/hypr/scripts/powerctl \
    .local/bin/triton-run-session-command \
    .local/bin/triton-mimeclip \
    .local/bin/triton-platform \
    .local/bin/triton-connect-session \
    .local/bin/triton-linux-session-cleanup
do
    target=$fresh_home/$relative
    if [ ! -L "$target" ] || [ ! -e "$target" ]; then
        echo "Expected a valid Stow link at $target" >&2
        exit 1
    fi
done

HOME=$fresh_home "$repo_dir/install.sh" uninstall >/dev/null
HOME=$fresh_home "$repo_dir/install.sh" uninstall >/dev/null
for relative in \
    .config/hypr/scripts/run-session-command \
    .config/hypr/scripts/start-session-quickshell \
    .config/quickshell \
    .local/bin/triton-run-session-command \
    .local/bin/triton-connect-session \
    .local/bin/triton-linux-session-cleanup
do
    if [ -L "$fresh_home/$relative" ]; then
        echo "Uninstaller left a Triton Desktop link at $fresh_home/$relative" >&2
        exit 1
    fi
done
if [ "$(cat "$fresh_home/.config/quickshell/notification-times.ini")" != 'local notification settings' ]; then
    echo "Uninstaller changed a local Quickshell override." >&2
    exit 1
fi
for override in \
    .config/fcitx5/conf/cached_layouts \
    .local/share/applications/elio.desktop \
    .local/share/flatpak/overrides/app.zen_browser.zen
do
    if [ ! -f "$fresh_home/$override" ]; then
        echo "Uninstaller removed the local override $override" >&2
        exit 1
    fi
done
if [ "$(cat "$fresh_home/.config/user-app/settings.ini")" != 'user-owned settings' ] || \
    [ "$(readlink "$fresh_home/.local/bin/user-app-data")" != "$fresh_home/.local/share/user-app/data" ]; then
    echo "Uninstaller changed unrelated user data or a user-owned symlink." >&2
    exit 1
fi

conflict_home=$tmp_dir/conflict-home
conflict=$conflict_home/.config/hypr/scripts/powerctl
mkdir -p "$(dirname -- "$conflict")"
printf '%s\n' 'user-owned file' >"$conflict"
if HOME=$conflict_home "$repo_dir/install.sh" >"$tmp_dir/conflict.log" 2>&1; then
    echo "Installer unexpectedly accepted a conflicting user file." >&2
    exit 1
fi
if [ "$(cat "$conflict")" != 'user-owned file' ] || [ -e "$conflict_home/.config/quickshell" ]; then
    echo "Installer changed user data or partially installed before reporting a conflict." >&2
    exit 1
fi

parent_conflict_home=$tmp_dir/parent-conflict-home
mkdir -p "$parent_conflict_home/.config"
printf '%s\n' 'user-owned file' >"$parent_conflict_home/.config/quickshell"
if HOME=$parent_conflict_home "$repo_dir/install.sh" >"$tmp_dir/parent-conflict.log" 2>&1; then
    echo "Installer unexpectedly accepted a file where a configuration directory is required." >&2
    exit 1
fi
if [ "$(cat "$parent_conflict_home/.config/quickshell")" != 'user-owned file' ] || \
    ! grep -F 'exists but a directory is required' "$tmp_dir/parent-conflict.log" >/dev/null || \
    [ -e "$parent_conflict_home/.config/hypr" ]; then
    echo "Installer did not safely reject the regular-file parent conflict." >&2
    cat "$tmp_dir/parent-conflict.log" >&2
    exit 1
fi

setup_bin=$tmp_dir/setup-bin
mkdir -p "$setup_bin"
cat >"$setup_bin/pacman" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$CALL_LOG"
EOF
cat >"$setup_bin/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
chmod +x "$setup_bin/pacman" "$setup_bin/sudo"
printf 'ID=cachyos\nID_LIKE="arch"\n' >"$tmp_dir/setup-os-release"
: >"$tmp_dir/setup-package-calls"
if printf 'none\n' | HOME=$conflict_home \
    PATH="$setup_bin:/usr/bin:/bin" \
    CALL_LOG=$tmp_dir/setup-package-calls \
    TRITON_OS_RELEASE_FILE=$tmp_dir/setup-os-release \
    "$repo_dir/install.sh" setup >"$tmp_dir/setup-conflict.log" 2>&1; then
    echo "Setup unexpectedly proceeded despite a Stow destination conflict." >&2
    exit 1
fi
if [ -s "$tmp_dir/setup-package-calls" ] || ! grep -F 'Install conflict:' "$tmp_dir/setup-conflict.log" >/dev/null; then
    echo "Setup installed packages before checking Stow conflicts." >&2
    cat "$tmp_dir/setup-conflict.log" >&2
    cat "$tmp_dir/setup-package-calls" >&2
    exit 1
fi

setup_home=$tmp_dir/setup-home
mkdir -p "$setup_home"
: >"$tmp_dir/setup-package-calls"
printf 'none\n' | HOME=$setup_home \
    PATH="$setup_bin:/usr/bin:/bin" \
    CALL_LOG=$tmp_dir/setup-package-calls \
    TRITON_OS_RELEASE_FILE=$tmp_dir/setup-os-release \
    "$repo_dir/install.sh" setup >/dev/null 2>&1
if ! grep -Fx -- '-S --needed git stow hyprland quickshell hypridle hyprpaper xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent bash jq python procps-ng imagemagick playerctl brightnessctl kitty' "$tmp_dir/setup-package-calls" >/dev/null; then
    echo "Setup did not request the selected base and core package set." >&2
    cat "$tmp_dir/setup-package-calls" >&2
    exit 1
fi
for relative in .config/hypr/scripts/powerctl .config/quickshell/shell.qml; do
    if [ ! -L "$setup_home/$relative" ] || [ ! -e "$setup_home/$relative" ]; then
        echo "Setup did not deploy the expected configuration link: $relative" >&2
        exit 1
    fi
done
for relative in .config/fish/config.fish .config/fcitx5/config .local/share/flatpak/overrides/net.ankiweb.Anki .config/nvim/init.lua; do
    if [ -L "$setup_home/$relative" ]; then
        echo "Setup deployed an optional config despite the 'none' selection: $relative" >&2
        exit 1
    fi
done

selected_home=$tmp_dir/selected-home
mkdir -p "$selected_home"
printf '6,9\n' | HOME=$selected_home \
    PATH="$setup_bin:/usr/bin:/bin" \
    CALL_LOG=$tmp_dir/setup-package-calls \
    TRITON_OS_RELEASE_FILE=$tmp_dir/setup-os-release \
    "$repo_dir/install.sh" setup >/dev/null 2>&1
for relative in .config/fish/config.fish .config/fcitx5/config; do
    if [ ! -L "$selected_home/$relative" ] || [ ! -e "$selected_home/$relative" ]; then
        echo "Setup did not deploy the selected optional config: $relative" >&2
        exit 1
    fi
done
for relative in .local/share/flatpak/overrides/net.ankiweb.Anki .config/nvim/init.lua; do
    if [ -L "$selected_home/$relative" ]; then
        echo "Setup deployed an unselected optional config: $relative" >&2
        exit 1
    fi
done

root_bin=$tmp_dir/root-bin
mkdir -p "$root_bin"
cat >"$root_bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] || exit 2
printf '%s\n' 0
EOF
chmod +x "$root_bin/id"
if HOME=$setup_home PATH="$root_bin:/usr/bin:/bin" "$repo_dir/install.sh" >"$tmp_dir/root-install.log" 2>&1; then
    echo "Installer unexpectedly allowed root execution." >&2
    exit 1
fi
if ! grep -F 'Do not run the Triton Desktop installer as root' "$tmp_dir/root-install.log" >/dev/null; then
    echo "Installer did not explain its root execution refusal." >&2
    cat "$tmp_dir/root-install.log" >&2
    exit 1
fi

"$repo_dir/tests/test-package-detection.sh"
"$repo_dir/tests/test-package-ownership.sh"
"$repo_dir/tests/test-platform-detection.sh"
"$repo_dir/tests/test-mimeclip-resolver.sh"

echo "Installer fresh, repeat, and conflict checks passed."
