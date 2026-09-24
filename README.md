# regueiro-hyprland

Personal dotfiles for my work-in-progress Hyprland setup with a custom QuickShell bar and panels, built for a consistent, responsive desktop. Feel free to use as inspiration but expect rough edges.

## Stack

- **WM** — [Hyprland](https://hyprland.org/)
- **Bar / panels** — [QuickShell](https://quickshell.outfoxxed.me/) (custom QML)
- **Launcher / power menu** — [QuickShell](https://quickshell.outfoxxed.me/) (custom QML)
- **Wallpaper** — [hyprpaper](https://github.com/hyprwm/hyprpaper)
- **Lock screen** — Quickshell with system PAM authentication
- **Input method** — [Fcitx 5](https://fcitx-im.org/wiki/Fcitx_5/en)
- **Terminal** — [Kitty](https://sw.kovidgoyal.net/kitty/)
- **Shell** — [Fish](https://fishshell.com/) + [Starship](https://starship.rs/)

## Lock screen

**Super+L**, the power menu, the 20-minute idle timeout, and suspend use the standalone Quickshell locker. Type immediately to reveal the password field; Enter or the arrow submits your Linux password. Escape clears the field and returns to the clock without unlocking. The session unlocks only after successful authentication.

The lock screen includes read-only battery/charging and volume indicators, plus a brief OSD when brightness, volume, or mute changes. These are rendered inside the lock surfaces; they do not expose the bar or desktop controls.

The entry point is `quickshell/.config/quickshell/lock.qml`. It uses Wayland's `ext-session-lock-v1` on every display and `/etc/pam.d/login`, retaining the system's password and failed-attempt policy. It runs separately from the bar, with file watching disabled. The launcher disables core dumps and external input-method integration for password entry. Passwords are not written to files or logs; QML strings cannot provide a guarantee of zeroing every in-memory copy.

`hypr/.config/hypr/scripts/quickshell-lock` supervises the process and retries up to three times after an unexpected exit. Hyprland's `allow_session_lock_restore` lets Quickshell recover while the compositor keeps the session locked. Hypridle uses `inhibit_sleep = 3` to wait for the compositor's lock notification. The power menu refuses to suspend unless Quickshell confirms its lock.

To lock manually:

```bash
~/.config/hypr/scripts/quickshell-lock
```

If automatic recovery fails, sign in on a TTY and relaunch Quickshell in the correct Hyprland instance (find its ID with `hyprctl instances`):

```bash
hyprctl -i INSTANCE dispatch 'hl.dsp.exec_cmd("~/.config/hypr/scripts/quickshell-lock")'
```

Do not kill or forcibly clear a live lock to unlock it. Compositor crash behavior, suspend/resume, and graphics-driver failures are outside the QML authentication tests; keep those limits in mind when changing this security-sensitive code.

The previous Hyprlock theme remains in the repository as an inactive configuration; no lock action launches it. The password eye toggles visibility and resets to hidden on submission or cancellation. `LOCK_WALLPAPER=file:///absolute/path/to/image` can override the wallpaper.

## Dependencies

The package commands below target CachyOS/Arch. Shared configuration also supports Fedora; package names and availability differ.

```sh
sudo pacman -S git stow \
               hyprland hyprpaper hyprpicker hypridle \
               hyprpolkitagent \
               quickshell \
               kitty fish starship fastfetch btop \
               fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool \
               nautilus \
               networkmanager \
               bluez bluez-utils blueman \
               pipewire pipewire-pulse wireplumber libpulse libcanberra sound-theme-freedesktop \
               wl-clipboard wl-clip-persist \
               brightnessctl playerctl \
               jq grim slurp libnotify \
               xorg-xhost \
               power-profiles-daemon \
               flatpak \
               adwaita-fonts cantarell-fonts \
               adw-gtk-theme
```

> Some of these may already be installed or available under slightly different names depending on your repos/AUR helper.
> Region screenshots use `grim` + `slurp`. `hyprpicker` is only used by the color-picker bind, `flatpak` is only needed if you keep the Zen Browser bind or want Flatpak apps in the launcher, and the Quick Settings power mode switcher uses `power-profiles-daemon` through QuickShell’s PowerProfiles interface.

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

QuickShell uses **Adwaita Sans** and **Cantarell**. On Arch, install them explicitly with `adwaita-fonts` and `cantarell-fonts`.

### Services

```sh
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
sudo systemctl enable --now power-profiles-daemon
```

On Fedora, keep `tuned-ppd` if it already provides power profiles. QuickShell uses the same PowerProfiles interface with either backend; it does not require `powerprofilesctl`.

### Privileged desktop apps

`hyprpolkitagent` provides the polkit authentication prompt under Hyprland, so apps that need admin privileges, like Btrfs Assistant, can ask for your password.
`xorg-xhost` provides the `xhost` helper some older/root X11 apps still expect under Wayland/XWayland, such as GParted.

### Launcher icons

The launcher caches icons as PNGs. For SVG conversion, install `rsvg-convert`
(`librsvg` on CachyOS/Arch, `librsvg2-tools` on Fedora) or ImageMagick as a fallback.

### Wallpaper previews

The picker prepares reusable JPEG previews in `$XDG_CACHE_HOME/quickshell/wallpaper-thumbnails-v1` (normally `~/.cache`). Install Python 3 and ImageMagick for preview generation. New or modified wallpapers are processed in the background; the first preparation can take a moment. Applying a wallpaper always uses the original image.

### Local overrides

The shared monitor layout, brightness stops, and Fish greeting remain the defaults. Optional
machine-local files under `$XDG_CONFIG_HOME` (normally `~/.config`) can override them:

- `hypr-local/monitors.lua`: replaces monitor configuration. `HYPR_PREFERRED_MONITOR`
  selects startup focus, defaulting to `DP-1`. Workspace assignments remain in
  `conf/workspaces.lua` unless also overridden.
- `quickshell-local/brightness.json`: an integer `step` (1–100) enables linear
  percentage-point adjustments; `minimum` (0–99, default 2) sets the lower bound.
  Without a valid step, the original stops apply. Edits reload automatically.
- `fish-local/config.fish`: sourced after the shared Fish configuration. To skip
  Fastfetch on terminal startup, define an empty `function fish_greeting; end` here.

Keep these files outside Stow and version control.

### Portals and Elio file chooser

Install `xdg-desktop-portal-hyprland` and `xdg-desktop-portal-gtk`, then Stow
`xdg-portals`. Startup handles both plain and UWSM-managed Hyprland sessions.
The desktop-specific `hyprland-portals.conf` leaves GNOME's portal selection alone.
When upgrading, remove the old `~/.config/xdg-desktop-portal/portals.conf` **only
if it is a symlink into this repo**, then restow `xdg-portals`.

Elio integration requires `xdg-desktop-portal-termfilechooser`, `kitty`, and an
`elio` build supporting `--chooser-file`. GTK is the fallback when termfilechooser
is unavailable; it is not automatic recovery from a running backend that fails.
To select GTK explicitly, set `org.freedesktop.impl.portal.FileChooser=gtk` in the
Hyprland portal preference file and rerun `~/.config/hypr/scripts/start-portals.sh`.

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
Install `mimeclip` / `mimeclipd` and its user service separately. Hyprland starts
the service through its autostart config; do not enable it globally for GNOME.
If previously enabled, run `systemctl --user disable mimeclipd` (without `--now`
to leave a running Hyprland instance alone). The service should use
`PartOf=graphical-session.target` so it stops with the graphical session.

### Input method

The current setup uses **Fcitx 5** with Spanish and Mozc Japanese input (`fcitx5` + `fcitx5-mozc`).
For broad app coverage on Hyprland/Wayland, keep the GTK and Qt integration packages installed too: `fcitx5-gtk` and `fcitx5-qt`.
Fcitx runs only in Hyprland; GNOME retains its own IBus input sources. The session sets `QT_IM_MODULE=fcitx`, `XMODIFIERS=@im=fcitx`, `SDL_IM_MODULE=fcitx`, and `GLFW_IM_MODULE=fcitx`. Leave `GTK_IM_MODULE` unset so GTK uses native Wayland input and avoids Fcitx’s startup warning. For a legacy GTK/XWayland app that needs the module, launch only that app with `env GTK_IM_MODULE=fcitx app-command`.

`fcitx-session.sh` starts Fcitx, selects Spanish, and stops its process when Hyprland exits. The `fcitx5` Stow package disables the standard global autostart entry.
`Super+Space` cycles the configured Spanish/Mozc group. The keyboard config uses `kb_options = lv3:switch`, so Right Ctrl acts as an additional AltGr key.

When upgrading, back up conflicting files before Stowing `gtk` and `fcitx5`. Remove old global Fcitx environment exports, separate Fcitx autostart services, and `gtk-im-module=fcitx` entries in non-stowed GTK files. Keep input-method variables scoped to Hyprland, outside shell profiles and the shared systemd/D-Bus environment.

Log out and back in after applying these changes. Simultaneous graphical sessions for the same user share input-method D-Bus services and are not supported by this setup.

### Optional keybind-only apps

```sh
flatpak install flathub app.zen_browser.zen
```

Homebrew is optional; Fish initializes it only when `/home/linuxbrew/.linuxbrew/bin/brew` is installed.

Some personal keybinds also expect `anitrack`, `elio`, `enzo`, and `runin`. The NormCap keybind prefers native `normcap`, then falls back to Flatpak `com.github.dynobo.normcap`.
The Fish config selects `ANI_CLI_PLAYER=enzo-mpv` whenever the wrapper is installed, so both normal terminal launches and the `Super+W` anime tracker bind use Enzo. The wrapper is stowed by the `hypr` package to `~/.local/bin/enzo-mpv` and forwards the media URL to `enzo`.
If you do not use those apps, either skip them or change the matching binds in `hypr/.config/hypr/conf/binds.lua`.

### Screenshots

Both Print Screen and F9 use the same screenshot actions:

| Action | Shortcuts |
| --- | --- |
| Current display | `Print` or `F9` |
| Selected area | `Shift+Print` or `Shift+F9` |
| Active window | `Alt+Print` or `Alt+F9` |

### Power menu

Power actions are handled by QuickShell through `qs ipc call powermenu`, so the session power menu expects the QuickShell daemon started by Hyprland autostart to be running.

## Install

```sh
git clone https://github.com/MiguelRegueiro/regueiro-hyprland ~/regueiro-hyprland
cd ~/regueiro-hyprland
stow --no-folding hypr quickshell fish starship fastfetch kitty hypridle fcitx5 gtk xdg-portals
```

Restow the affected packages after pulling changes that add or rename files. Existing Stow symlinks already point at updated files; machine-local overrides remain outside the checkout.

## Formatting

Use the repo scripts instead of running `qmlformat` blindly over the whole tree:

```sh
./scripts/format-configs.sh
./scripts/check-configs.sh
```

`quickshell/.config/quickshell/services/NotificationStore.qml` is intentionally excluded from automatic `qmlformat`.
That file stays manually formatted because forcing `qmlformat` on it caused notification regressions.
