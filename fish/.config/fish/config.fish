if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Load fzf key bindings
if test -f /usr/share/fzf/shell/key-bindings.fish
    source /usr/share/fzf/shell/key-bindings.fish
end
functions -q fzf_key_bindings; and fzf_key_bindings


# Distro-aware updater abbreviation.
if test -f /etc/os-release
    if grep -qiE '(^ID=fedora$|^ID_LIKE=.*fedora)' /etc/os-release
        abbr -a up "sudo dnf upgrade --refresh -y && flatpak update -y && cargo install-update -a"
    else
        abbr -a up "paru -Syu && flatpak update && cargo install-update -a"
    end
end

fish_add_path $HOME/.local/bin
if command -sq starship
    starship init fish | source
end


function __refresh_fastfetch_package_cache --description "Refresh cached package counts for fastfetch"
    set -l cache_dir "$HOME/.cache/fastfetch"
    set -l cache_file "$cache_dir/packages.txt"
    mkdir -p $cache_dir

    set -l counts

    if command -sq pacman
        set -l pacman_count (pacman -Qq 2>/dev/null | wc -l | string trim)
        test -n "$pacman_count"; and set -a counts "$pacman_count (pacman)"
    end

    if command -sq flatpak
        set -l flatpak_system_count (flatpak list --system 2>/dev/null | wc -l | string trim)
        test -n "$flatpak_system_count"; and set -a counts "$flatpak_system_count (flatpak-system)"

        set -l flatpak_user_count (flatpak list --user 2>/dev/null | wc -l | string trim)
        test -n "$flatpak_user_count"; and set -a counts "$flatpak_user_count (flatpak-user)"
    end

    if test -x /home/linuxbrew/.linuxbrew/bin/brew
        set -l brew_count (/home/linuxbrew/.linuxbrew/bin/brew list 2>/dev/null | wc -l | string trim)
        test -n "$brew_count"; and set -a counts "$brew_count (brew)"
    end

    if test (count $counts) -gt 0
        printf '%s\n' (string join ', ' $counts) > $cache_file
    end
end

# Keep fastfetch on launch without recalculating package counts every time.
function fish_greeting
    set -l cache_file "$HOME/.cache/fastfetch/packages.txt"
    set -l refresh_interval 43200

    if not test -f $cache_file
        __refresh_fastfetch_package_cache >/dev/null 2>&1 &
    else
        set -l now (date +%s)
        set -l mtime (stat -c %Y $cache_file 2>/dev/null)
        if test -n "$mtime"
            if test (math "$now - $mtime") -gt $refresh_interval
                __refresh_fastfetch_package_cache >/dev/null 2>&1 &
            end
        end
    end

    if command -sq fastfetch
        fastfetch
    end
end
