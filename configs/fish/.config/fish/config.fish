if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Override CachyOS's Fastfetch greeting without disabling its other Fish defaults.
function fish_greeting
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

# Text selection in Fish's command-line editor (provided by natural-selection).
function fish_user_key_bindings
    if functions --query _natural_selection
        bind escape '_natural_selection end-selection'
        bind left '_natural_selection backward-char'
        bind right '_natural_selection forward-char'
        bind up '_natural_selection up-or-search'
        bind down '_natural_selection down-or-search'
        bind ctrl-left '_natural_selection backward-token'
        bind ctrl-right '_natural_selection forward-token'
        bind ctrl-up '_natural_selection up-line'
        bind ctrl-down '_natural_selection down-line'
        bind shift-left '_natural_selection backward-char --is-selecting'
        bind shift-right '_natural_selection forward-char --is-selecting'
        bind shift-up '_natural_selection up-line --is-selecting'
        bind shift-down '_natural_selection down-line --is-selecting'
        bind ctrl-shift-left '_natural_selection backward-word --is-selecting'
        bind ctrl-shift-right '_natural_selection forward-word --is-selecting'
        bind ctrl-shift-up '_natural_selection up-line --is-selecting'
        bind ctrl-shift-down '_natural_selection down-line --is-selecting'
        bind '' kill-selection end-selection self-insert
    end
end

# Keep ani-cli/anitrack on the terminal-native Enzo player in regular shells,
# not only when launched through the dedicated Hyprland keybind.
if command -sq enzo-mpv
    set -gx ANI_CLI_PLAYER enzo-mpv
    set -gx ANI_CLI_NO_DETACH 1
end

if command -sq zoxide
    zoxide init fish | source
end

if command -sq starship
    starship init fish | source
end


if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv fish | source
end

# Apply machine-local overrides after the shared configuration.
if test -f "$__fish_config_dir/../fish-local/config.fish"
    source "$__fish_config_dir/../fish-local/config.fish"
end
