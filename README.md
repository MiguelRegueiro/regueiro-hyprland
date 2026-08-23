# regueiro-hyprland

FreeBSD-only Hyprland dotfiles for my laptop desktop. The setup is a custom QuickShell shell on top of Hyprland, tuned for FreeBSD 15.1, Intel graphics, Linuxulator Discord, Firefox VAAPI playback, and a GNOME-like workflow without using GNOME.

This is personal infrastructure. Use it as reference, but expect hardware-specific paths, monitor names, and helper scripts.

Machine-specific copy-paste notes live in [docs/freebsd-hardware-notes.md](docs/freebsd-hardware-notes.md). Keep the README as the reusable FreeBSD source of truth; use the hardware notes only when rebuilding this exact laptop or checking what was done locally.

## Stack

- **OS** - FreeBSD 15.1
- **Compositor** - Hyprland
- **Bar / panels / launcher / power menu** - QuickShell
- **Wallpaper** - hyprpaper
- **Lock / idle** - hyprlock + hypridle
- **Polkit agent** - hyprpolkitagent
- **Terminal** - Kitty
- **Shell** - Fish + Starship
- **Keyboard** - Spanish layout through Hyprland
- **Audio** - PipeWire + WirePlumber, with PulseAudio compatibility
- **Portals** - xdg-desktop-portal + xdg-desktop-portal-hyprland
- **Browser** - Firefox on Wayland with Intel VAAPI
- **Discord** - linux-discord through Linuxulator/XWayland

## Packages

Core packages:

```sh
doas pkg install -y git gh stow \
    hyprland hypridle hyprlock hyprpaper hyprpicker hyprpolkitagent \
    quickshell \
    kitty xterm fish starship fastfetch btop elio \
    nautilus \
    pipewire wireplumber pulseaudio freedesktop-sound-theme \
    seatd dbus polkit xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    drm-61-kmod gpu-firmware-intel-kmod-kabylake \
    libva libva-intel-media-driver libva-utils \
    wl-clipboard cliphist grim slurp playerctl jq \
    bsdisks fusefs-ext2 e2fsprogs upower \
    linux_base-rl9 linux-discord \
    noto noto-basic noto-emoji liberation-fonts-ttf dejavu \
    cpu-microcode-intel cpu-microcode-rc
```

Optional packages depending on what you use:

```sh
doas pkg install -y webcamd fswebcam fd-find
```

`webcamd` is only needed if the webcam does not work through the default stack.
On FreeBSD, the package that provides `fd` is `fd-find`:

```sh
doas pkg install fd-find
```

## System Setup

Configure desktop services and the required kernel modules:

```sh
doas sysrc dbus_enable=YES
doas sysrc seatd_enable=YES
doas sysrc linux_enable=YES
doas sysrc powerd_enable=NO
doas sysrc -x powerd_flags
doas sysrc kld_list="i915kms acpi_video ng_ubt ng_hci ng_l2cap ng_btsocket ext2fs fusefs"

doas service dbus start
doas service seatd start
```

### pkg

The tracked `pkg/pkg.conf` changes interactive pkg prompts to default to yes
(`[Y/n]`) while still allowing cancellation. Install it as a root-owned system
configuration rather than stowing it:

```sh
doas install -o root -g wheel -m 644 pkg/pkg.conf /usr/local/etc/pkg.conf
```

Configure `doas` manually as root-owned system policy, not through stow. The
tracked `docs/doas.conf.example` mirrors the current local
`/usr/local/etc/doas.conf`, so it can be copied directly when rebuilding the
setup:

```sh
doas cp docs/doas.conf.example /usr/local/etc/doas.conf
doas chmod 644 /usr/local/etc/doas.conf
doas -C /usr/local/etc/doas.conf
```

This local policy is convenient for a single-user laptop, but permissive because
wheel can run commands without a password and with the environment preserved.
For a stricter setup, remove the sample user rules and replace the broad wheel
rules with `permit persist :wheel`.

Enable early Intel microcode loading:

```sh
doas sysrc -f /boot/loader.conf cpu_microcode_load=YES
doas sysrc -f /boot/loader.conf cpu_microcode_name=/boot/firmware/intel-ucode.bin
doas sysrc -x -f /boot/loader.conf hint.hwpstate_intel.0.disabled
doas sysrc -f /boot/loader.conf machdep.hwpstate_pkg_ctrl=0
```

Reboot after changing `/boot/loader.conf` or `kld_list`.

On this HP Pavilion x360, keep `hwpstate_intel` enabled but disable HWP package
control with `machdep.hwpstate_pkg_ctrl="0"`. The validated runtime uses
per-core HWP with EPP 50 on CPUs 0-7 and leaves `powerd` disabled. The old
`est0` plus `powerd` workaround is obsolete; EPP 0 and 100 both performed
significantly worse than 50 in real benchmarks.

### Intel DRM Driver

This laptop currently uses `drm-61-kmod` with `i915kms`. Avoid the generic
`drm-kmod` meta package here, because after the FreeBSD 15.1 update it pulled
`drm-66-kmod`, which caused a black-screen reboot loop before the TTY login.

Known-good recovery package:

```sh
doas pkg install -y drm-61-kmod
```

If a newer DRM branch is tested later, keep a single-user-mode recovery path
ready and be prepared to remove the bad driver from `/etc/rc.conf` or reinstall
`drm-61-kmod`.

The user should be in at least these groups:

```sh
pw groupmod wheel -m "$USER"
pw groupmod operator -m "$USER"
pw groupmod video -m "$USER"
```

External drive support uses `bsdisks` as the UDisks2-compatible backend.
Install `e2fsprogs` for ext2/3/4 inspection/repair tools. Keep `ext2fs`
loaded for FreeBSD's native ext driver, and keep `fusefs-ext2` available only
as a compatibility fallback. If either module was not already included in
`kld_list`, load it at boot:

```sh
doas sysrc kld_list+="ext2fs fusefs"
doas kldload ext2fs
doas kldload fusefs
```

Prefer the native ext driver in `bsdisks`; `fuse-ext2` can issue tiny 4K reads
and make large copies crawl:

```sh
doas sed -i .bak -e 's/^prefer_native_ext2 = false$/prefer_native_ext2 = true/' /usr/local/etc/bsdisks.conf
```

FreeBSD's native ext driver is the practical choice for fast read-only access
to Linux ext4 USB drives. For a USB drive shared read/write between Linux and
FreeBSD, exFAT is usually the smoother filesystem.

## Install

```sh
git clone https://github.com/MiguelRegueiro/regueiro-hyprland ~/regueiro-hyprland
cd ~/regueiro-hyprland
stow hypr quickshell fish starship fastfetch kitty gtk xresources discord runin elio fontconfig mimeapps user-dirs desktop-overrides
```

The `hypr` package owns the active Hyprland config, including `hypridle.conf`.
There is no separate `hypridle` stow package because it would target the same
file and create a conflict.

Install cursor and fonts:

```sh
ln -sfn ~/regueiro-hyprland/icons/MacTahoe-dark ~/.local/share/icons/MacTahoe-dark
cp -r icons/Bibata-Modern-Classic ~/.local/share/icons/
mkdir -p ~/.icons
ln -sfn ~/.local/share/icons/MacTahoe-dark ~/.icons/MacTahoe-dark
ln -s ~/.local/share/icons/Bibata-Modern-Classic ~/.icons/Bibata-Modern-Classic

cp -r fonts/. ~/.local/share/fonts/
fc-cache -fv
```

The `~/.icons` symlink matters for Linuxulator/XWayland apps such as Discord.

Xresources is stow-managed at `~/.Xresources`. Hyprland loads it at startup
with `xrdb`, so xterm uses the configured dark theme, DPI, and
`JetBrainsMono Nerd Font Mono` fallback-terminal font automatically. To apply
changes in the current session without logging out:

```sh
xrdb -merge ~/.Xresources
```

Launch Hyprland with the fish `hr` abbreviation, which expands to the
stow-managed `~/.start-hyprland` wrapper:

```sh
hr
```

The wrapper runs `ck-launch-session dbus-run-session start-hyprland`. This is
required for polkit to treat the Hyprland login as an active local session.
Without it, file managers and QuickShell/`udisksctl` can see USB drives but
fail to mount them with `Not authorized`.

After logging into Hyprland, this should list an active session:

```sh
ck-list-sessions
```

## Hyprland Notes

The compositor config uses Hyprland's native Lua API and requires Hyprland
0.55 or newer. `hypr/.config/hypr/hyprland.lua` is the entrypoint and loads the
focused modules under `hypr/.config/hypr/conf/`. The `hypridle.conf`,
`hyprlock.conf`, and `hyprpaper.conf` files remain in their programs' native
config formats.

When switching an existing session from `hyprland.conf` to `hyprland.lua`, log
out and start Hyprland again. A normal `hyprctl reload` keeps the config
provider selected when the compositor started.

FreeBSD installs `hyprpolkitagent` at `/usr/local/libexec/hyprpolkitagent`, so autostart must use the full path:

```lua
hl.exec_cmd("/usr/local/libexec/hyprpolkitagent")
```

The checked-in monitor config is for this laptop. Adjust `hypr/.config/hypr/conf/monitors.lua` if your monitor names differ, and see [docs/freebsd-hardware-notes.md](docs/freebsd-hardware-notes.md) for the current hardware-specific values.

XWayland should render unscaled so Electron apps can scale themselves cleanly:

```lua
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
```

This is especially important for Discord font rendering.

Wallpaper is applied through `hyprpaper` in Hyprland autostart:

```lua
hl.exec_cmd("hyprpaper")
```

System suspend is disabled in QuickShell on this laptop. FreeBSD reports S3
support, but real tests with `zzz` froze the machine hard enough to require a
forced power-off.

Hypridle still locks on normal idle timeout and turns the display off with
DPMS. Do not enable automatic system suspend unless S3 resume is fixed and
tested outside the desktop session first.

## Firefox / YouTube Performance

Install and verify the Intel VAAPI driver:

```sh
doas pkg install -y libva-intel-media-driver libva-utils
vainfo
```

Expected useful entries include:

- `VAProfileH264High`
- `VAProfileVP9Profile0`
- `VAProfileHEVCMain`

The Hyprland session exports:

```lua
hl.env("LIBVA_DRIVER_NAME", "iHD")
hl.env("MOZ_ENABLE_WAYLAND", "1")
```

Firefox profile prefs used for smooth YouTube playback:

```js
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.av1.enabled", false);
user_pref("gfx.webrender.all", true);
user_pref("widget.dmabuf.force-enabled", true);
```

`media.av1.enabled = false` matters on this Intel Comet Lake iGPU. YouTube AV1 playback is CPU decoded, while VP9/H.264 can be GPU decoded through VAAPI.

## Discord

Discord uses `linux-discord` through Linuxulator. Keep it on XWayland. Forcing Electron Wayland/Ozone caused EGL/VAAPI errors and high CPU usage on this machine.

### Update Override

The Linux Discord wrapper can overwrite `settings.json` from `settings.json.bak`, which can re-enable the upstream host update prompt. Keep the update override immutable:

```sh
./scripts/setup-discord-runtime.sh
```

To edit it later:

```sh
doas chflags noschg ~/.config/discord/settings.json
```

### Font And Cursor Rendering

The working setup is:

- Hyprland `xwayland.force_zero_scaling = true`
- Discord launched with `--force-device-scale-factor=1.25`
- Cursor theme exported through the launcher
- No custom `FONTCONFIG_FILE`
- Xft DPI loaded through `xrdb`
- xterm kept as a dark fallback terminal using `JetBrainsMono Nerd Font Mono`

Relevant `~/.Xresources` values:

```conf
Xft.dpi: 120
Xft.antialias: true
Xft.hinting: true
Xft.hintstyle: hintslight
Xft.rgba: rgb
XTerm*faceName: JetBrainsMono Nerd Font Mono
XTerm*faceSize: 15
XTerm*background: #0b0d10
XTerm*foreground: #d7dae0
```

Hyprland loads it automatically on startup. To apply changes in the current
session:

```sh
xrdb -merge ~/.Xresources
```

The Discord desktop-file override is stow-managed at `discord/.local/share/applications/linux-discord.desktop`:

```ini
[Desktop Entry]
Name=Discord
StartupWMClass=discord
Comment=All-in-one voice and text chat.
GenericName=Internet Messenger
Exec=env XCURSOR_THEME=Bibata-Modern-Classic XCURSOR_SIZE=24 GTK_THEME=Adwaita:dark /usr/local/bin/linux-discord --force-device-scale-factor=1.25
Icon=discord
Type=Application
Categories=Network;InstantMessaging;
Path=/usr/local/bin
```

Do not use:

```sh
--force-device-scale-factor=0.9
--enable-features=UseOzonePlatform --ozone-platform=wayland
FONTCONFIG_FILE=...
```

Those caused blurry fonts, broken text rendering, or high CPU usage in Linux Discord.

If Discord text breaks after experiments, stop Discord and clear generated caches:

```sh
pkill -f "$HOME/.config/discord"
mv ~/.config/discord/Cache ~/.config/discord/Cache.bak
mv ~/.config/discord/'Code Cache' ~/.config/discord/'Code Cache.bak'
mv ~/.config/discord/GPUCache ~/.config/discord/GPUCache.bak
```

Then restart from the desktop-file launcher.

Do not stow the full `~/.config/discord` profile. It contains tokens, cookies, caches, and other runtime state. Only the update override in `settings.json` is worth recreating, and it is documented in [docs/freebsd-hardware-notes.md](docs/freebsd-hardware-notes.md).

## QuickShell Services

Some QuickShell services are FreeBSD-specific:

- Wi-Fi uses FreeBSD helper scripts.
- Bluetooth uses FreeBSD `hccontrol` / service helpers.
- Power mode uses a FreeBSD-specific helper, but its `performance` preset is not
  recommended on this laptop: it starts `powerd` and selects EPP 0. The
  validated configuration keeps `powerd` disabled and uses per-core HWP at
  EPP 50.
- SSH sessions use `who`, `ps`, `sockstat`, and `pkill` to show active logins
  in the bar and end same-user sessions from the menu.
- Battery, brightness, disks, and audio are wired to the FreeBSD device/service model.

QuickShell and the Hyprland volume scripts use the freedesktop volume-change
sound for audible volume feedback. Install the sound theme if it is missing:

```sh
doas pkg install freedesktop-sound-theme
```

Power actions are handled by QuickShell through:

```sh
qs ipc call powermenu
```

The Hyprland autostart must start QuickShell:

```lua
hl.exec_cmd("qs -n -d")
```

## Keyboard

The Hyprland keyboard config uses:

```lua
hl.config({
    input = {
        kb_options = "lv3:switch",
    },
})
```

Right Ctrl acts as an additional AltGr / level-3 key, useful on the Spanish layout.

Japanese input is not enabled in this FreeBSD config. The Linux setup uses
Fcitx 5 Mozc, but FreeBSD does not provide the same Fcitx 5 Mozc package. The
tested Fcitx 5 Anthy path did not produce reliable kana/kanji input on this
machine, so Fcitx is intentionally omitted here.

## Hardware Notes

This laptop uses:

- Intel Comet Lake UHD as the real display GPU.
- NVIDIA MX250 as a secondary dGPU.
- Realtek `rtw88` Wi-Fi.
- BOE `BOE082C` / `NV140FHM-N4K` panel.

The NVIDIA MX250 is intentionally ignored. It is not worth the complexity for this desktop, and the internal panel is driven by Intel.

The BOE panel is low-gamut. Software calibration can improve tone curve behavior, but it cannot make the display color accurate.

## Formatting

Use the repo scripts instead of running `qmlformat` blindly over the whole tree:

```sh
./scripts/format-configs.sh
./scripts/check-configs.sh
```

`quickshell/.config/quickshell/services/NotificationStore.qml` is intentionally excluded from automatic `qmlformat`.
That file stays manually formatted because forcing `qmlformat` on it caused notification regressions.
