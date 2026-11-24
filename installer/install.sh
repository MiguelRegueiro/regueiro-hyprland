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

# Moving a Stow package can leave links to its former top-level path dangling.
# Find those links even when they pointed at empty directories (such as the
# Quickshell screenshot cache), which have no source files for the package loop
# below to discover.
find "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" -type l -print 2>/dev/null |
while IFS= read -r link_path; do
    [ -e "$link_path" ] && continue
    link=$(readlink "$link_path")
    case "$link" in
        *regueiro-hyprland/hypr/*|*regueiro-hyprland/hypridle/*|*regueiro-hyprland/quickshell/*|*regueiro-hyprland/fish/*|*regueiro-hyprland/starship/*|*regueiro-hyprland/fastfetch/*|*regueiro-hyprland/kitty/*|*regueiro-hyprland/fcitx5/*|*regueiro-hyprland/gtk/*|*regueiro-hyprland/xdg-portals/*|*regueiro-hyprland/flatpak/*|*regueiro-hyprland/nvim/*|*regueiro-hyprland/mimeclip/*|*regueiro-hyprland/fonts/*|*regueiro-hyprland/icons/*|*regueiro-hyprland/wallpapers/*|*regueiro-hyprland/easytts/*|*regueiro-hyprland/dictation/*)
            rm "$link_path"
            ;;
    esac
done

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
                        case "$link" in
                            *regueiro-hyprland/hypr/*|*regueiro-hyprland/hypridle/*|*regueiro-hyprland/quickshell/*|*regueiro-hyprland/fish/*|*regueiro-hyprland/starship/*|*regueiro-hyprland/fastfetch/*|*regueiro-hyprland/kitty/*|*regueiro-hyprland/fcitx5/*|*regueiro-hyprland/gtk/*|*regueiro-hyprland/xdg-portals/*|*regueiro-hyprland/flatpak/*|*regueiro-hyprland/nvim/*|*regueiro-hyprland/mimeclip/*)
                                rm "$parent"
                                ;;
                        esac
                    fi
                    parent=$(dirname "$parent")
                done
                if [ -L "$target" ] && [ ! -e "$target" ]; then
                    link=$(readlink "$target")
                    case "$link" in
                        *regueiro-hyprland/hypr/*|*regueiro-hyprland/hypridle/*|*regueiro-hyprland/quickshell/*|*regueiro-hyprland/fish/*|*regueiro-hyprland/starship/*|*regueiro-hyprland/fastfetch/*|*regueiro-hyprland/kitty/*|*regueiro-hyprland/fcitx5/*|*regueiro-hyprland/gtk/*|*regueiro-hyprland/xdg-portals/*|*regueiro-hyprland/flatpak/*|*regueiro-hyprland/nvim/*|*regueiro-hyprland/mimeclip/*)
                            rm "$target"
                            ;;
                    esac
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
stow_packages configs fish kitty starship fastfetch gtk fcitx5 mimeclip nvim xdg-portals flatpak

printf '%s\n' "Triton Desktop configuration linked. Log out and back in to start the session changes."
