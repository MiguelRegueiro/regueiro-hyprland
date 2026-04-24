# regueiro-hyprland

Personal dotfiles for my work-in-progress Hyprland setup with a custom QuickShell bar and panels, aiming for a GNOME-like experience but faster and more customizable. Feel free to use as inspiration but expect rough edges.

## Stack

- **WM** — [Hyprland](https://hyprland.org/)
- **Bar / panels** — [QuickShell](https://quickshell.outfoxxed.me/) (custom QML)
- **Launcher** — [Rofi](https://github.com/davatorium/rofi)
- **Wallpaper** — [hyprpaper](https://github.com/hyprwm/hyprpaper)
- **Lock screen** — [hyprlock](https://github.com/hyprwm/hyprlock)
- **Input method** — [ibus](https://github.com/ibus/ibus)
- **Terminal** — [Kitty](https://sw.kovidgoyal.net/kitty/)
- **Shell** — [Fish](https://fishshell.com/) + [Starship](https://starship.rs/)

## Dependencies

```sh
sudo pacman -S hyprland hyprpaper hyprlock hyprpicker hypridle \
               quickshell \
               rofi \
               kitty fish starship fastfetch btop \
               ibus \
               nautilus \
               network-manager-applet blueman \
               wl-clipboard cliphist wl-clip-persist \
               fcitx5 \
               brightnessctl playerctl \
               adw-gtk-theme
```

> Some of these may already be installed or available under slightly different names depending on your repos/AUR helper.

AUR (install with paru or yay):

```sh
paru -S normcap elio-bin
```

## Manual steps

### Bibata cursor theme

```sh
cp -r icons/Bibata-Modern-Classic ~/.local/share/icons/
```

### Fonts

The `fonts/` folder contains all needed fonts. Install them by copying to your fonts directory:

```sh
cp -r fonts/. ~/.local/share/fonts/
fc-cache -fv
```

QuickShell also uses **Adwaita Sans** and **Cantarell** which come with GNOME/adwaita packages.

### runin (Super+Shift+Return)

```sh
cargo install runin
```

### Monitor layout

`hyprland.conf` has a hardcoded monitor layout for my machine. Edit the `### MONITORS ###` section to match yours before starting.

## Install

```sh
git clone https://github.com/MiguelRegueiro/regueiro-hyprland ~/regueiro-hyprland
cd ~/regueiro-hyprland
stow hypr quickshell rofi fish starship fastfetch kitty fcitx5 hypridle
```
