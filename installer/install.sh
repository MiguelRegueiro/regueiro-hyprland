#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
action=${1:-install}

case "$action" in
    install|update) ;;
    packages)
        shift
        exec "$repo_dir/installer/packages/install.sh" "$@"
        ;;
    *) echo "Usage: ./install.sh [install|update|packages]" >&2; exit 2 ;;
esac

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required. Install it with your distribution package manager, then rerun ./install.sh." >&2
    exit 1
fi

is_legacy_link() {
    case "$1" in
        *regueiro-hyprland/*)
            return 0
            ;;
        *) return 1 ;;
    esac
}

is_local_override() {
    case "$1" in
        .local/share/applications/elio.desktop|.local/share/flatpak/overrides/app.zen_browser.zen|.config/quickshell/notification-times.ini|.config/fcitx5/conf/cached_layouts)
            return 0
            ;;
        *) return 1 ;;
    esac
}

preflight_package() {
    package_dir=$1
    package=$2
    package_root=$repo_dir/$package_dir/$package
    [ -d "$package_root" ] || return 0

    find "$package_root" -type f | while IFS= read -r source; do
        relative=${source#"$package_root"/}
        target=$HOME/$relative
        target_relative=${target#"$HOME"/}
        is_local_override "$target_relative" && continue

        parent=$(dirname "$target")
        while [ "$parent" != "$HOME" ] && [ "$parent" != / ]; do
            if [ -L "$parent" ]; then
                if [ ! -e "$parent" ]; then
                    link=$(readlink "$parent")
                    if is_legacy_link "$link"; then
                        break
                    fi
                    printf 'Install conflict: %s is a dangling symlink not owned by this migration.\n' "$parent" >&2
                    exit 1
                fi
                expected_parent=$package_root/${parent#"$HOME"/}
                if [ ! -d "$parent" ] || [ ! -d "$expected_parent" ] || [ "$(realpath "$parent")" != "$(realpath "$expected_parent")" ]; then
                    printf 'Install conflict: %s is an existing symlink directory.\n' "$parent" >&2
                    exit 1
                fi
            fi
            parent=$(dirname "$parent")
        done

        if [ -L "$target" ]; then
            if [ -e "$target" ] && [ "$(realpath "$target")" = "$(realpath "$source")" ]; then
                continue
            fi
            link=$(readlink "$target")
            if [ ! -e "$target" ] && is_legacy_link "$link"; then
                continue
            fi
            printf 'Install conflict: %s is an existing symlink to another target.\n' "$target" >&2
            exit 1
        fi
        if [ -e "$target" ]; then
            printf 'Install conflict: %s already exists; move it or add it to your local overrides.\n' "$target" >&2
            exit 1
        fi
    done
}

preflight_packages() {
    package_dir=$1
    shift
    for package do
        preflight_package "$package_dir" "$package"
    done
}

# Detect all destination conflicts before removing old links or creating any
# new ones, so a failed install leaves the current desktop untouched.
preflight_packages compositors/hyprland hypr hypridle
preflight_packages desktop quickshell scripts
platform_package=linux
if [ "$(uname -s)" = FreeBSD ]; then
    platform_package=freebsd
fi
preflight_packages platforms "$platform_package"
preflight_packages configs fish kitty starship fastfetch gtk fcitx5 mimeclip nvim xdg-portals flatpak

stow_packages() {
    package_dir=$1
    shift
    for package do
        package_root=$repo_dir/$package_dir/$package
        if [ -d "$package_root" ]; then
            # Remove only broken Stow links that still point at this checkout's
            # former top-level package paths. Leave real files and unrelated
            # symlinks untouched for GNU Stow to report as conflicts.
            find "$package_root" -type f | while IFS= read -r source; do
                relative=${source#"$package_root"/}
                target=$HOME/$relative
                parent=$(dirname "$target")
                while [ "$parent" != "$HOME" ] && [ "$parent" != / ]; do
                    if [ -L "$parent" ] && [ ! -e "$parent" ]; then
                        link=$(readlink "$parent")
                        if is_legacy_link "$link"; then rm "$parent"; fi
                    fi
                    parent=$(dirname "$parent")
                done
                if [ -L "$target" ] && [ ! -e "$target" ]; then
                    link=$(readlink "$target")
                    if is_legacy_link "$link"; then rm "$target"; fi
                fi
            done
            # Keep machine-local application overrides that already exist as
            # regular files. They are intentionally not replaced by Stow.
            case "$package_dir/$package" in
                compositors/hyprland/hypr)
                    stow --no-folding --ignore='^\.local/share/applications/elio\.desktop$' \
                        --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
                    ;;
                desktop/quickshell)
                    stow --no-folding --ignore='notification-times\.ini$' \
                        --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
                    ;;
                configs/fcitx5)
                    stow --no-folding --ignore='cached_layouts$' \
                        --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
                    ;;
                configs/flatpak)
                    stow --no-folding --ignore='^\.local/share/flatpak/overrides/app\.zen_browser\.zen$' \
                        --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
                    ;;
                *)
                    stow --no-folding --dir="$repo_dir/$package_dir" --target="$HOME" "$package"
                    ;;
            esac
        fi
    done
}

# The public installer applies the current Hyprland desktop profile. OS package
# installation is a separate, explicit operation in installer/packages/.
stow_packages compositors/hyprland hypr hypridle
stow_packages desktop quickshell
stow_packages desktop scripts
stow_packages platforms "$platform_package"
if [ "$platform_package" = freebsd ]; then
    TRITON_DESKTOP_DIR="$repo_dir" "$HOME/.local/bin/triton-freebsd-build-hardware"
fi
stow_packages configs fish kitty starship fastfetch gtk fcitx5 mimeclip nvim xdg-portals flatpak

# Remove dangling links left by files deleted in earlier refactors. Keep this
# sweep limited to Stow-managed locations and the old checkout's unique path.
for managed_root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"; do
    [ -d "$managed_root" ] || continue
    find "$managed_root" -type l -lname '*regueiro-hyprland/*' -print |
        while IFS= read -r stale_link; do
            [ -e "$stale_link" ] || rm "$stale_link"
        done
done

printf '%s\n' "Triton Desktop configuration linked. Log out and back in to start the session changes."
