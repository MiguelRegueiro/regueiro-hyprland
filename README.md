# regueiro-hyprland

Personal dotfiles for my work-in-progress Hyprland setup with a custom QuickShell bar and panels, aiming for a GNOME-like experience but faster and more customizable. Feel free to use as inspiration but expect rough edges.

## Stack

- **WM** — [Hyprland](https://hyprland.org/)
- **Bar / panels** — [QuickShell](https://quickshell.outfoxxed.me/) (custom QML)
- **Launcher** — [QuickShell](https://quickshell.outfoxxed.me/) (custom QML)
- **Run / power menus** — [Rofi](https://github.com/davatorium/rofi)
- **Wallpaper** — [hyprpaper](https://github.com/hyprwm/hyprpaper)
- **Lock screen** — [hyprlock](https://github.com/hyprwm/hyprlock)
- **Input method** — [Fcitx 5](https://fcitx-im.org/wiki/Fcitx_5/en)
- **Terminal** — [Kitty](https://sw.kovidgoyal.net/kitty/)
- **Shell** — [Fish](https://fishshell.com/) + [Starship](https://starship.rs/)

## Dependencies

```sh
sudo pacman -S git stow \
               hyprland hyprpaper hyprlock hyprpicker hypridle \
               hyprpolkitagent \
               quickshell \
               rofi \
               kitty fish starship fastfetch btop \
               fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool \
               nautilus \
               networkmanager \
               bluez bluez-utils blueman \
               pipewire pipewire-pulse wireplumber libpulse \
               wl-clipboard wl-clip-persist \
               brightnessctl playerctl \
               jq grim slurp swappy libnotify \
               xorg-xhost \
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

### Privileged desktop apps

`hyprpolkitagent` provides the polkit authentication prompt under Hyprland, so apps that need admin privileges, like Btrfs Assistant, can ask for your password.
`xorg-xhost` provides the `xhost` helper some older/root X11 apps still expect under Wayland/XWayland, such as GParted.

### Monitor layout

`hypr/.config/hypr/conf/monitors.conf` has a hardcoded monitor layout for my machine. Edit it to match yours before starting.

### Wi-Fi handling

Wi-Fi is handled directly inside the QuickShell quick settings panel through `nmcli`.
No NetworkManager applet is used in this setup, so secured networks use the custom QuickShell password prompt and inline error states instead of a separate GTK dialog.
On Arch, the package is `networkmanager`, but the binaries you actually use are `nmcli` and `NetworkManager`.

### Bluetooth handling

The Bluetooth submenu is handled directly with `bluetoothctl`, so `bluez` + `bluez-utils` are the core Bluetooth dependencies.
It currently lists paired devices and lets you connect/disconnect them inline from QuickShell.
`blueman` is also part of this setup: `blueman-applet` is autostarted, and the footer button opens `blueman-manager` for the external Bluetooth settings/pairing UI.

### Clipboard history

Clipboard history is handled by [`mimeclip`](https://github.com/MiguelRegueiro/mimeclip), not `cliphist`.
Install `mimeclip` / `mimeclipd` separately, then enable its user service:

```sh
systemctl --user enable --now mimeclipd
```

### Input method

The current setup uses **Fcitx 5** with Spanish and Mozc Japanese input (`fcitx5` + `fcitx5-mozc`).
For broad app coverage on Hyprland/Wayland, keep the GTK and Qt integration packages installed too: `fcitx5-gtk` and `fcitx5-qt`.
The session exports `XMODIFIERS=@im=fcitx`, `QT_IM_MODULE=fcitx`, and `GLFW_IM_MODULE=fcitx` so GLFW apps such as Kitty use the same input-method backend.
GTK uses the native Wayland frontend for modern apps, while the repo's GTK settings files keep `fcitx` configured for GTK apps that still run through X11/XWayland.
The top-bar language indicator is backed by a QuickShell input service that tracks the real Fcitx method ID and the configured method order from the current Fcitx group.
`Super+Space` cycles through the configured group order through QuickShell first so the OSD and shell state stay in sync, and falls back to the direct Fcitx backend if QuickShell is unavailable.
After the first install or after changing the IM env vars, log out and back in once so the session picks up the new input-method setup.
If `stow gtk` conflicts with existing `~/.config/gtk-3.0/settings.ini` or `~/.config/gtk-4.0/settings.ini`, back them up and retry:

```sh
mv ~/.config/gtk-3.0/settings.ini ~/.config/gtk-3.0/settings.ini.bak
mv ~/.config/gtk-4.0/settings.ini ~/.config/gtk-4.0/settings.ini.bak
stow gtk
```

If you want to keep existing GTK settings instead, merge `gtk-im-module=fcitx` into those files manually.

### Optional keybind-only apps

```sh
flatpak install flathub app.zen_browser.zen
```

Some personal keybinds also expect `anitrack`, `elio`, `normcap`, and `runin`.
If you do not use those apps, either skip them or change the matching binds in `hypr/.config/hypr/conf/binds.conf`.

## Install

```sh
git clone https://github.com/MiguelRegueiro/regueiro-hyprland ~/regueiro-hyprland
cd ~/regueiro-hyprland
stow hypr quickshell rofi fish starship fastfetch kitty hypridle fcitx5 gtk
```

## Formatting

Use the repo scripts instead of running `qmlformat` blindly over the whole tree:

```sh
./scripts/format-configs.sh
./scripts/check-configs.sh
```

`quickshell/.config/quickshell/services/NotificationStore.qml` is intentionally excluded from automatic `qmlformat`.
That file stays manually formatted because forcing `qmlformat` on it caused notification regressions.
