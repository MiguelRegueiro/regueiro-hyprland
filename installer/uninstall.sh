#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$(id -u)" -eq 0 ]; then
    echo "Do not run the Triton Desktop uninstaller as root; it removes user configuration." >&2
    exit 1
fi
remove_packages=no
if [ "${1:-}" = --packages ]; then
    remove_packages=yes
    shift
fi
[ "$#" -eq 0 ] || { echo "Usage: ./install.sh uninstall [--packages]" >&2; exit 2; }

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required to safely remove Triton Desktop configuration links." >&2
    exit 1
fi

. "$repo_dir/installer/packages/root.sh"

file_sha256() {
    if command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        return 1
    fi
}

remove_package() {
    package_dir=$1
    package=$2
    package_root=$repo_dir/$package_dir/$package
    [ -d "$package_root" ] || return 0

    case "$package_dir/$package" in
        compositors/hyprland/hypr)
            stow --delete --no-folding --ignore='^\.local/share/applications/elio\.desktop$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
            ;;
        desktop/quickshell)
            stow --delete --no-folding --ignore='notification-times\.ini$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
            ;;
        configs/fcitx5)
            stow --delete --no-folding --ignore='cached_layouts$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
            ;;
        configs/flatpak)
            stow --delete --no-folding --ignore='^\.local/share/flatpak/overrides/app\.zen_browser\.zen$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
            ;;
        *)
            stow --delete --no-folding --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
            ;;
    esac
}

# Remove links for the current checkout, including a platform package from a
# previous OS install. Stow leaves real files and links owned by other targets.
for package in hypr hypridle; do
    remove_package compositors/hyprland "$package"
done
for package in quickshell scripts; do
    remove_package desktop "$package"
done
for package in linux freebsd; do
    remove_package desktop/platforms "$package"
done
for package in fish kitty starship fastfetch gtk fcitx5 mimeclip nvim xdg-portals flatpak; do
    remove_package configs "$package"
done

# The selected optional groups are installer state, not user configuration.
selection_file=${XDG_STATE_HOME:-$HOME/.local/state}/triton-desktop/package-groups
if [ -f "$selection_file" ] && [ ! -L "$selection_file" ]; then
    rm -f "$selection_file"
fi

remove_asset_link() {
    target=$1
    expected=$2
    if [ -L "$target" ] && [ "$(realpath "$target")" = "$(realpath "$expected")" ]; then
        rm "$target"
    fi
}
remove_asset_link "${XDG_DATA_HOME:-$HOME/.local/share}/fonts/triton-desktop" \
    "$repo_dir/desktop/assets/fonts"
remove_asset_link "${XDG_DATA_HOME:-$HOME/.local/share}/icons/Bibata-Modern-Classic" \
    "$repo_dir/desktop/assets/icons/Bibata-Modern-Classic"
remove_asset_link "${XDG_DATA_HOME:-$HOME/.local/share}/triton-desktop/assets" \
    "$repo_dir/desktop/assets"

hardware_target=$HOME/.local/bin/triton-freebsd-hardware
hardware_manifest=${XDG_STATE_HOME:-$HOME/.local/state}/triton-desktop/generated/triton-freebsd-hardware.sha256
if [ -L "$hardware_manifest" ]; then
    echo "Preserving $hardware_target because its Triton ownership record is a symlink." >&2
elif [ -f "$hardware_manifest" ]; then
    recorded_checksum=$(cat "$hardware_manifest")
    if [ ! -e "$hardware_target" ]; then
        rm -f "$hardware_manifest"
    elif [ -f "$hardware_target" ] && [ ! -L "$hardware_target" ] && \
        [ "$(file_sha256 "$hardware_target" 2>/dev/null || true)" = "$recorded_checksum" ]; then
        rm -f "$hardware_target" "$hardware_manifest"
    else
        echo "Preserving $hardware_target because it no longer matches Triton Desktop's recorded generated binary." >&2
    fi
fi

if [ "$remove_packages" = yes ]; then
    state_dir=${TRITON_PACKAGE_STATE_DIR:-$HOME/.local/state/triton-desktop/packages}
    for manifest in "$state_dir"/*.list; do
        [ -f "$manifest" ] || continue
        manager=${manifest##*/}
        manager=${manager%.list}
        query_command=$(package_query_command "$manager") || {
            printf 'Unknown package manager in manifest: %s (leaving it unchanged).\n' "$manager" >&2
            continue
        }
        if ! command -v "$query_command" >/dev/null 2>&1; then
            printf 'Cannot inspect packages for %s: %s is unavailable (leaving the manifest unchanged).\n' "$manager" "$query_command" >&2
            continue
        fi
        set --
        while IFS= read -r package || [ -n "$package" ]; do
            [ -n "$package" ] || continue
            if package_is_installed "$manager" "$package"; then
                set -- "$@" "$package"
            fi
        done <"$manifest"
        [ "$#" -gt 0 ] || { rm -f "$manifest"; continue; }

        printf 'Packages recorded as installed by Triton (%s):\n' "$manager"
        for package do printf '  %s\n' "$package"; done
        printf 'Remove these packages? Type "remove" to confirm: '
        answer=
        IFS= read -r answer || answer=
        if [ "$answer" != remove ]; then
            printf '%s\n' 'Keeping recorded packages.'
            continue
        fi

        case "$manager" in
            arch) run_as_root pacman -R -- "$@" ;;
            debian|debian-backports) run_as_root apt remove "$@" ;;
            fedora) run_as_root dnf remove "$@" ;;
            freebsd) run_as_root pkg delete "$@" ;;
            void) run_as_root xbps-remove "$@" ;;
            *) echo "Unknown package manager in manifest: $manager" >&2; continue ;;
        esac
        rm -f "$manifest"
    done
fi

# Clean only dangling links left by deleted files in Triton/legacy checkout
# paths. Never remove a valid link or a link that points elsewhere.
for managed_root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"; do
    [ -d "$managed_root" ] || continue
    find "$managed_root" -type l \
        \( -lname '*regueiro-hyprland/*' \
    -o -lname "$repo_dir/*" \) -print |
        while IFS= read -r stale_link; do
            [ -e "$stale_link" ] || rm "$stale_link"
        done
done

if [ "$remove_packages" = yes ]; then
    printf '%s\n' "Triton Desktop configuration links were removed. Recorded package manifests were removed only after successful package-manager removal. Personal files were left untouched. Log out and back in to end the session."
else
    printf '%s\n' "Triton Desktop configuration links removed. Installed packages and personal files were left untouched. Log out and back in to end the session."
fi
