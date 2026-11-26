#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
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
        -o -lname '*triton-desktop/*' \) -print |
        while IFS= read -r stale_link; do
            [ -e "$stale_link" ] || rm "$stale_link"
        done
done

if [ "$remove_packages" = yes ]; then
    printf '%s\n' "Triton Desktop configuration links were removed. Recorded package manifests were removed only after successful package-manager removal. Personal files were left untouched. Log out and back in to end the session."
else
    printf '%s\n' "Triton Desktop configuration links removed. Installed packages and personal files were left untouched. Log out and back in to end the session."
fi
