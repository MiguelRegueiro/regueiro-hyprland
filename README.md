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
sudo pacman -S git stow \
               hyprland hyprpaper hyprlock hyprpicker hypridle \
               quickshell \
               rofi \
               kitty fish starship fastfetch btop \
               ibus ibus-anthy fcitx5 \
               nautilus \
               networkmanager \
               bluez bluez-utils blueman \
               pipewire pipewire-pulse wireplumber libpulse \
               wl-clipboard cliphist wl-clip-persist \
               brightnessctl playerctl \
               jq grim slurp swappy libnotify \
               power-profiles-daemon \
               flatpak \
               adw-gtk-theme
```

> Some of these may already be installed or available under slightly different names depending on your repos/AUR helper.
> `swappy` is only needed for annotated screenshots, and `power-profiles-daemon` is only needed for the Quick Settings power mode switcher.

Optional / personal extras:

```sh
paru -S normcap elio-bin
cargo install runin
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

### Services

```sh
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon
```

### Monitor layout

`hyprland.conf` has a hardcoded monitor layout for my machine. Edit the `### MONITORS ###` section to match yours before starting.

### Wi-Fi handling

Wi-Fi is handled directly inside the QuickShell quick settings panel through `nmcli`.
`nm-applet` is not autostarted in this setup, so secured networks use the custom QuickShell password prompt and inline error states instead of the GTK NetworkManager dialog.
On Arch, the package is `networkmanager`, but the binaries you actually use are `nmcli` and `NetworkManager`.

### Bluetooth handling

The Bluetooth submenu is handled directly with `bluetoothctl`, so `bluez` + `bluez-utils` are the core Bluetooth dependencies.
It currently lists paired devices and lets you connect/disconnect them inline from QuickShell.
The footer button opens `blueman-manager`, which comes from `blueman`, so keep `blueman` installed if you want the external Bluetooth settings/pairing app.

### Input method

The current setup uses **IBus** with Spanish and Anthy (`ibus` + `ibus-anthy`).
The `fcitx5/` folder is kept intentionally as an alternative Japanese input-method path while I decide which stack I want long term.
It is not enabled by default in the current Hyprland session, but the package is listed above because that config is kept on purpose.

### Optional keybind-only apps

```sh
flatpak install flathub app.zen_browser.zen
```

Some personal keybinds also expect `anitrack`, `elio`, `normcap`, and `runin`.
If you do not use those apps, either skip them or change the matching binds in `hyprland.conf`.

## Install

```sh
git clone https://github.com/MiguelRegueiro/regueiro-hyprland ~/regueiro-hyprland
cd ~/regueiro-hyprland
stow hypr quickshell rofi fish starship fastfetch kitty hypridle
```
