#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
action=${1:-install}
config_only=no

case "$action" in
    install|update) ;;
    --config-only)
        [ "$#" -eq 1 ] || { echo "Usage: ./install.sh [--config-only]" >&2; exit 2; }
        action=install
        config_only=yes
        ;;
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
if [ -L "$selection_file" ]; then
    echo "Install conflict: $selection_file is a symlink; move it before installing." >&2
    exit 1
fi
setup_mode=no
if [ "$action" = setup ]; then
    setup_mode=yes
    selected_groups=$("$repo_dir/installer/packages/install.sh" --profile hyprland --select-groups)
elif [ -r "$selection_file" ]; then
    selected_groups=$(cat "$selection_file")
elif [ "$action" = install ] && [ "$config_only" = no ] && [ -t 0 ] && \
    [ ! -L "$HOME/.config/quickshell/shell.qml" ] && \
    [ ! -L "$HOME/.config/hypr/scripts/start-session-quickshell" ]; then
    setup_mode=yes
    selected_groups=$("$repo_dir/installer/packages/install.sh" --profile hyprland --select-groups)
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

file_sha256() {
    if command -v sha256 >/dev/null 2>&1; then
        sha256 -q "$1"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{ print $1 }'
    else
        echo "A SHA-256 utility is required to track the generated FreeBSD bridge." >&2
        return 1
    fi
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
hardware_target=$HOME/.local/bin/triton-freebsd-hardware
hardware_state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/triton-desktop/generated
hardware_manifest=$hardware_state_dir/triton-freebsd-hardware.sha256
if [ "$platform_package" = freebsd ]; then
    hardware_parent=$(dirname "$hardware_target")
    if [ -e "$hardware_parent" ] && [ ! -d "$hardware_parent" ]; then
        echo "Install conflict: $hardware_parent exists but a directory is required." >&2
        exit 1
    fi
    if [ -L "$hardware_target" ]; then
        echo "Install conflict: $hardware_target is a symlink; move it before installing the FreeBSD bridge." >&2
        exit 1
    fi
    if [ -L "$hardware_manifest" ]; then
        echo "Install conflict: $hardware_manifest is a symlink; move it before installing." >&2
        exit 1
    fi
    if [ -e "$hardware_target" ]; then
        current_hardware_checksum=$(file_sha256 "$hardware_target")
        recorded_hardware_checksum=$(cat "$hardware_manifest" 2>/dev/null || true)
        if [ -z "$recorded_hardware_checksum" ] || [ "$current_hardware_checksum" != "$recorded_hardware_checksum" ]; then
            echo "Install conflict: $hardware_target exists and is not an unchanged Triton-generated binary." >&2
            exit 1
        fi
    fi
fi
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
if [ "$setup_mode" = yes ]; then
    "$repo_dir/installer/packages/install.sh" --profile hyprland --groups "$selected_groups"
    "$repo_dir/installer/features/install-mimeclip.sh"
fi

hardware_tmp=
hardware_backup=
hardware_manifest_backup=
hardware_installed=no
hardware_was_owned=no
hardware_manifest_existed=no
hardware_install_tmp=
hardware_manifest_tmp=
hardware_manifest_written=no
selection_tmp=
selection_backup=
selection_existed=no
selection_written=no
asset_install_done=no
new_asset_links=
cleanup_hardware_tmp() {
    [ -z "$hardware_tmp" ] || rm -f "$hardware_tmp"
    [ -z "$hardware_backup" ] || rm -f "$hardware_backup"
    [ -z "$hardware_manifest_backup" ] || rm -f "$hardware_manifest_backup"
    [ -z "$hardware_install_tmp" ] || rm -f "$hardware_install_tmp"
    [ -z "$hardware_manifest_tmp" ] || rm -f "$hardware_manifest_tmp"
    [ -z "$selection_tmp" ] || rm -f "$selection_tmp"
    [ -z "$selection_backup" ] || rm -f "$selection_backup"
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
    if [ "$result" -ne 0 ] && { [ "$hardware_installed" = yes ] || [ "$hardware_manifest_written" = yes ]; }; then
        if [ "$hardware_was_owned" = yes ] && [ -n "$hardware_backup" ]; then
            install -m 0755 "$hardware_backup" "$hardware_target" || \
                echo "Rollback could not restore $hardware_target." >&2
        else
            rm -f "$hardware_target"
        fi
        if [ "$hardware_manifest_existed" = yes ] && [ -n "$hardware_manifest_backup" ]; then
            cp "$hardware_manifest_backup" "$hardware_manifest" || \
                echo "Rollback could not restore $hardware_manifest." >&2
        else
            rm -f "$hardware_manifest"
        fi
    fi
    if [ "$result" -ne 0 ] && [ "$selection_written" = yes ]; then
        if [ "$selection_existed" = yes ] && [ -n "$selection_backup" ]; then
            selection_restore=$(mktemp "$(dirname "$selection_file")/.package-groups-restore.XXXXXX")
            cp "$selection_backup" "$selection_restore" && mv "$selection_restore" "$selection_file" || {
                rm -f "$selection_restore"
                echo "Rollback could not restore the package-group selection." >&2
            }
        else
            rm -f "$selection_file"
        fi
    fi
    if [ "$result" -ne 0 ] && [ "$asset_install_done" = yes ]; then
        printf '%s\n' "$new_asset_links" | while IFS='|' read -r target source; do
            [ -n "$target" ] || continue
            if [ -L "$target" ] && [ "$(realpath "$target")" = "$(realpath "$source")" ]; then
                rm -f "$target"
            fi
        done
    fi
    cleanup_hardware_tmp
    exit "$result"
}
trap rollback_deployment EXIT
trap 'exit 1' HUP INT TERM
if [ "$platform_package" = freebsd ]; then
    hardware_tmp=$(mktemp "${TMPDIR:-/tmp}/triton-hardware.XXXXXX")
    if [ -e "$hardware_target" ]; then
        hardware_was_owned=yes
        hardware_backup=$(mktemp "${TMPDIR:-/tmp}/triton-hardware-backup.XXXXXX")
        cp "$hardware_target" "$hardware_backup"
    fi
    if [ -f "$hardware_manifest" ]; then
        hardware_manifest_existed=yes
        hardware_manifest_backup=$(mktemp "${TMPDIR:-/tmp}/triton-hardware-state.XXXXXX")
        cp "$hardware_manifest" "$hardware_manifest_backup"
    fi
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

record_package_state() {
    package_dir=$1
    package=$2
    package_spec=$package_dir:$package
    case " $attempted_packages " in *" $package_spec "*) ;; *) attempted_packages="$attempted_packages $package_spec" ;; esac
    if package_was_stowed "$package_dir" "$package"; then
        case " $previous_packages " in *" $package_spec "*) ;; *) previous_packages="$previous_packages $package_spec" ;; esac
    fi
}

remove_deselected_optional_configs() {
    for package in fish starship fastfetch fcitx5 nvim flatpak; do
        case " $config_packages " in *" $package "*) continue ;; esac
        package_root=$repo_dir/configs/$package
        [ -d "$package_root" ] || continue
        if package_was_stowed configs "$package"; then
            deployment_active=yes
            record_package_state configs "$package"
            stow_delete_package configs "$package"
        fi
    done
}

# The public installer applies the current Hyprland desktop profile. OS package
# installation is a separate, explicit operation in installer/packages/.
remove_deselected_optional_configs
stow_packages compositors/hyprland hypr hypridle
stow_packages desktop quickshell
stow_packages desktop scripts
stow_packages desktop/platforms "$platform_package"
if [ "$platform_package" = freebsd ]; then
    hardware_install_tmp=$(mktemp "$HOME/.local/bin/.triton-freebsd-hardware.XXXXXX")
    install -m 0755 "$hardware_tmp" "$hardware_install_tmp"
    hardware_installed=yes
    mv -f "$hardware_install_tmp" "$hardware_target"
    hardware_install_tmp=
fi
stow_packages configs $config_packages

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

asset_data=${XDG_DATA_HOME:-$HOME/.local/share}
for asset_spec in \
    "$asset_data/fonts/triton-desktop|$repo_dir/desktop/assets/fonts" \
    "$asset_data/icons/Bibata-Modern-Classic|$repo_dir/desktop/assets/icons/Bibata-Modern-Classic" \
    "$asset_data/triton-desktop/assets|$repo_dir/desktop/assets"
do
    asset_target=${asset_spec%%|*}
    asset_source=${asset_spec#*|}
    if [ ! -e "$asset_target" ] && [ ! -L "$asset_target" ]; then
        new_asset_links="$new_asset_links
$asset_target|$asset_source"
    fi
done
"$repo_dir/installer/install-assets.sh"
asset_install_done=yes

if [ "$platform_package" = freebsd ]; then
    mkdir -p "$hardware_state_dir"
    hardware_manifest_tmp=$(mktemp "$hardware_state_dir/.triton-freebsd-hardware.XXXXXX")
    file_sha256 "$hardware_target" >"$hardware_manifest_tmp"
    hardware_manifest_written=yes
    mv "$hardware_manifest_tmp" "$hardware_manifest"
    hardware_manifest_tmp=
fi

mkdir -p "$(dirname "$selection_file")"
if [ -f "$selection_file" ]; then
    selection_existed=yes
    selection_backup=$(mktemp "${TMPDIR:-/tmp}/triton-groups-backup.XXXXXX")
    cp "$selection_file" "$selection_backup"
fi
selection_tmp=$(mktemp "$(dirname "$selection_file")/.package-groups.XXXXXX")
printf '%s\n' "$selected_groups" >"$selection_tmp"
selection_written=yes
mv "$selection_tmp" "$selection_file"
selection_tmp=

printf '%s\n' "Triton Desktop configuration linked. Log out and back in to start the session changes."
