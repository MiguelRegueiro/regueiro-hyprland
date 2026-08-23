# Miguel FreeBSD fish config
# Minimal, fast, FreeBSD-safe.
function fish_greeting
end

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less
set -gx LESS "-R"
set -gx BROWSER firefox
set -gx TERMINAL kitty

fish_add_path $HOME/.local/bin
fish_add_path $HOME/bin
fish_add_path /usr/local/bin
fish_add_path /usr/local/sbin

# Basic navigation.
abbr -a ll "ls -lah"
abbr -a la "ls -A"
abbr -a l "ls -lah"
abbr -a .. "cd .."
abbr -a ... "cd ../.."
abbr -a .... "cd ../../.."
abbr -a hr "~/.start-hyprland"
abbr -a sx startx

# Editor / doas.
abbr -a v nvim
abbr -a svim "doas nvim"
abbr -a se "doasedit"

# FreeBSD pkg.
abbr -a ps "pkg search"
abbr -a pi "doas pkg install"
abbr -a pr "doas pkg remove"
abbr -a pu "doas pkg update"
abbr -a pup "doas pkg upgrade"
abbr -a up "doas pkg upgrade && flatpak update"
abbr -a autoremove "doas pkg autoremove"

# FreeBSD services/system.
abbr -a rc "doas service"
abbr -a rcl "service -l"
abbr -a rcstatus "service -e"
abbr -a kld "kldstat"
abbr -a ports "cd /usr/ports"

# Git, if installed.
abbr -a gs "git status --short --branch"
abbr -a gd "git diff"
abbr -a gl "git log --oneline --decorate --graph -20"
abbr -a ga "git add"
abbr -a gc "git commit"
abbr -a gp "git push"

# Process/network helpers.
abbr -a portsopen "sockstat -4 -6 -l"
abbr -a myip "ifconfig | grep 'inet '"

# Optional extras if you install them later.
if command -sq zoxide
    zoxide init fish | source
end

if command -sq starship
    starship init fish | source
end
