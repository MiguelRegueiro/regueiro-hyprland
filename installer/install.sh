#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
action=${1:-install}

case "$action" in
    install|update) ;;
    setup)
        shift
        [ "$#" -eq 0 ] || { echo "Usage: ./install.sh setup" >&2; exit 2; }
        ;;
    uninstall)
        shift
        exec "$repo_dir/installer/uninstall.sh" "$@"
        ;;
    packages)
        shift
        exec "$repo_dir/installer/packages/install.sh" "$@"
        ;;
    *) echo "Usage: ./install.sh [install|update|setup|uninstall|packages]" >&2; exit 2 ;;
esac

if [ "$(id -u)" -eq 0 ]; then
    echo "Do not run the Triton Desktop installer as root; it installs user configuration." >&2
    exit 1
fi

selection_file=${XDG_STATE_HOME:-$HOME/.local/state}/triton-desktop/package-groups
if [ "$action" = setup ]; then
    selected_groups=$("$repo_dir/installer/packages/install.sh" --profile hyprland --select-groups)
elif [ -r "$selection_file" ]; then
    selected_groups=$(cat "$selection_file")
else
    selected_groups=all
fi

group_selected() {
    [ "$selected_groups" = all ] && return 0
    case ",$selected_groups," in *,"$1",*) return 0 ;; esac
    return 1
}

if [ "$selected_groups" = all ]; then
    config_packages='fish kitty starship fastfetch gtk fcitx5 mimeclip nvim xdg-portals flatpak'
else
    config_packages='kitty gtk mimeclip xdg-portals'
    group_selected terminal && config_packages="$config_packages fish starship fastfetch"
    group_selected input && config_packages="$config_packages fcitx5"
    group_selected editor && config_packages="$config_packages nvim"
    group_selected flatpak && config_packages="$config_packages flatpak"
fi

is_legacy_link() {
    case "$1" in
        *regueiro-hyprland/*|*triton-desktop/platforms/linux/*|*triton-desktop/platforms/freebsd/*)
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
            if [ -e "$parent" ] && [ ! -d "$parent" ]; then
                printf 'Install conflict: %s exists but a directory is required.\n' "$parent" >&2
                exit 1
            fi
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
preflight_packages desktop/platforms "$platform_package"
preflight_packages configs $config_packages
"$repo_dir/installer/install-assets.sh" --check

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is missing; installing the bootstrap packages with the native package manager."
    "$repo_dir/installer/packages/install.sh"
fi
if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is still unavailable after package installation." >&2
    exit 1
fi

stow_check_package() {
    package_dir=$1
    package=$2
    package_root=$repo_dir/$package_dir/$package
    [ -d "$package_root" ] || return 0
    case "$package_dir/$package" in
        compositors/hyprland/hypr)
            stow --simulate --no-folding --ignore='^\.local/share/applications/elio\.desktop$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" >/dev/null 2>&1 || {
                    echo "Stow preflight failed for $package_dir/$package." >&2; return 1;
                }
            ;;
        desktop/quickshell)
            stow --simulate --no-folding --ignore='notification-times\.ini$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" >/dev/null 2>&1 || {
                    echo "Stow preflight failed for $package_dir/$package." >&2; return 1;
                }
            ;;
        configs/fcitx5)
            stow --simulate --no-folding --ignore='cached_layouts$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" >/dev/null 2>&1 || {
                    echo "Stow preflight failed for $package_dir/$package." >&2; return 1;
                }
            ;;
        configs/flatpak)
            stow --simulate --no-folding --ignore='^\.local/share/flatpak/overrides/app\.zen_browser\.zen$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" >/dev/null 2>&1 || {
                    echo "Stow preflight failed for $package_dir/$package." >&2; return 1;
                }
            ;;
        *)
            stow --simulate --no-folding --dir="$repo_dir/$package_dir" --target="$HOME" "$package" >/dev/null 2>&1 || {
                echo "Stow preflight failed for $package_dir/$package." >&2; return 1;
            }
            ;;
    esac
}

for package in hypr hypridle; do stow_check_package compositors/hyprland "$package"; done
for package in quickshell scripts; do stow_check_package desktop "$package"; done
stow_check_package desktop/platforms "$platform_package"
for package in $config_packages; do
    stow_check_package configs "$package"
done

# The configuration simulation above must pass before installing the selected
# runtime profile. This keeps package changes out of ordinary Stow conflicts.
if [ "$action" = setup ]; then
    "$repo_dir/installer/packages/install.sh" --profile hyprland --groups "$selected_groups"
    "$repo_dir/installer/features/install-mimeclip.sh"
fi

hardware_tmp=
cleanup_hardware_tmp() {
    [ -z "$hardware_tmp" ] || rm -f "$hardware_tmp"
}
attempted_packages=
previous_packages=
deployment_active=no

stow_apply_package() {
    package_dir=$1
    package=$2
    case "$package_dir/$package" in
        compositors/hyprland/hypr)
            stow --no-folding --ignore='^\.local/share/applications/elio\.desktop$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        desktop/quickshell)
            stow --no-folding --ignore='notification-times\.ini$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        configs/fcitx5)
            stow --no-folding --ignore='cached_layouts$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        configs/flatpak)
            stow --no-folding --ignore='^\.local/share/flatpak/overrides/app\.zen_browser\.zen$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        *) stow --no-folding --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
    esac
}

stow_delete_package() {
    package_dir=$1
    package=$2
    case "$package_dir/$package" in
        compositors/hyprland/hypr)
            stow --delete --no-folding --ignore='^\.local/share/applications/elio\.desktop$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        desktop/quickshell)
            stow --delete --no-folding --ignore='notification-times\.ini$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        configs/fcitx5)
            stow --delete --no-folding --ignore='cached_layouts$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        configs/flatpak)
            stow --delete --no-folding --ignore='^\.local/share/flatpak/overrides/app\.zen_browser\.zen$' \
                --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
        *) stow --delete --no-folding --dir="$repo_dir/$package_dir" --target="$HOME" "$package" ;;
    esac
}

package_was_stowed() {
    package_dir=$1
    package=$2
    package_root=$repo_dir/$package_dir/$package
    marker=$(mktemp "${TMPDIR:-/tmp}/triton-stow-state.XXXXXX")
    find "$package_root" -type f | while IFS= read -r source; do
        relative=${source#"$package_root"/}
        target=$HOME/$relative
        if [ -L "$target" ] && [ -e "$target" ] && \
            [ "$(realpath "$target")" = "$(realpath "$source")" ]; then
            printf x >"$marker"
            break
        fi
    done
    result=1
    [ -s "$marker" ] && result=0
    rm -f "$marker"
    return "$result"
}

rollback_deployment() {
    result=$?
    trap - EXIT HUP INT TERM
    if [ "$result" -ne 0 ] && [ "$deployment_active" = yes ]; then
        echo "Configuration deployment failed; restoring the previous Stow links." >&2
        for spec in $attempted_packages; do
            package_dir=${spec%%:*}
            package=${spec#*:}
            stow_delete_package "$package_dir" "$package" >/dev/null 2>&1 || true
        done
        for spec in $previous_packages; do
            package_dir=${spec%%:*}
            package=${spec#*:}
            stow_apply_package "$package_dir" "$package" >/dev/null 2>&1 || \
                echo "Rollback could not restore $spec; inspect its Stow links manually." >&2
        done
    fi
    cleanup_hardware_tmp
    exit "$result"
}
trap rollback_deployment EXIT
trap 'exit 1' HUP INT TERM
if [ "$platform_package" = freebsd ]; then
    hardware_tmp=$(mktemp "${TMPDIR:-/tmp}/triton-hardware.XXXXXX")
    TRITON_DESKTOP_DIR="$repo_dir" TRITON_HARDWARE_OUTPUT="$hardware_tmp" \
        "$repo_dir/desktop/platforms/freebsd/.local/bin/triton-freebsd-build-hardware"
fi

stow_packages() {
    package_dir=$1
    shift
    for package do
        package_root=$repo_dir/$package_dir/$package
        if [ -d "$package_root" ]; then
            deployment_active=yes
            package_spec=$package_dir:$package
            case " $attempted_packages " in *" $package_spec "*) ;; *) attempted_packages="$attempted_packages $package_spec" ;; esac
            if package_was_stowed "$package_dir" "$package"; then
                case " $previous_packages " in *" $package_spec "*) ;; *) previous_packages="$previous_packages $package_spec" ;; esac
            fi
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
            stow_apply_package "$package_dir" "$package"
        fi
    done
}

# The public installer applies the current Hyprland desktop profile. OS package
# installation is a separate, explicit operation in installer/packages/.
stow_packages compositors/hyprland hypr hypridle
stow_packages desktop quickshell
stow_packages desktop scripts
stow_packages desktop/platforms "$platform_package"
if [ "$platform_package" = freebsd ]; then
    install -m 0755 "$hardware_tmp" "$HOME/.local/bin/triton-freebsd-hardware"
fi
stow_packages configs $config_packages

mkdir -p "$(dirname "$selection_file")"
selection_tmp=$(mktemp "$(dirname "$selection_file")/.package-groups.XXXXXX")
printf '%s\n' "$selected_groups" >"$selection_tmp"
mv "$selection_tmp" "$selection_file"

# Remove dangling links left by files deleted in earlier refactors. Keep this
# sweep limited to Stow-managed locations and the old checkout's unique path.
for managed_root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"; do
    [ -d "$managed_root" ] || continue
    find "$managed_root" -type l \
        \( -lname '*regueiro-hyprland/*' \
        -o -lname '*triton-desktop/platforms/linux/*' \
        -o -lname '*triton-desktop/platforms/freebsd/*' \) -print |
        while IFS= read -r stale_link; do
            [ -e "$stale_link" ] || rm "$stale_link"
        done
done

"$repo_dir/installer/install-assets.sh"

printf '%s\n' "Triton Desktop configuration linked. Log out and back in to start the session changes."
