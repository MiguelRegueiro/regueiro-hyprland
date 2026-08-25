# FreeBSD Hardware Notes

These notes are for the current laptop and are intentionally not all represented as stow-managed files. They include machine-specific device names, panel details, boot settings, and app-runtime state that should be copied carefully on a new machine.

## Machine

- OS: FreeBSD 15.1
- Laptop: HP Pavilion x360 Convertible 14-dh1xxx
- CPU: Intel Core i7-10510U
- Display GPU: Intel Comet Lake UHD, `8086:9b41`
- Secondary GPU: NVIDIA MX250, intentionally ignored
- Internal panel: BOE `BOE082C`, likely BOE `NV140FHM-N4K`
- Internal output: `eDP-1`
- Panel mode: `1920x1080@60`
- Hyprland scale: `1.25`
- Wi-Fi: Realtek RTL8822CE through `rtw88`

The NVIDIA MX250 is not worth configuring for this setup. The internal panel is driven by Intel, and the dGPU adds complexity and power draw.

## NVIDIA MX250 Suspension

This laptop's unused NVIDIA MX250 is at `pci0:2:0:0`; Intel i915 remains the
display GPU. The tracked rc service suspends the MX250 into PCI D3 during boot.
This is a machine-specific power-management workaround. In real use, such as
playing video or running a jail, the desktop feels drastically better: CPU
usage spikes less severely and recovers faster.

The PCI address is hardware-specific. Do not blindly reuse it on another
machine. Confirm the device address before installing or enabling the service.

Install the tracked script as a root-owned rc service:

```sh
doas install -o root -g wheel -m 555 rc.d/mx250_suspend /usr/local/etc/rc.d/mx250_suspend
```

Enable it with the other `/etc/rc.conf` settings below, then reboot. Verify the
device reached D3 with:

```sh
doas pciconf -lvc pci0:2:0:0 | grep powerspec
```

Expected output includes `current D3`.

Temporarily reverse the workaround without changing its boot-time setting:

```sh
doas devctl resume pci0:2:0:0
```

Re-suspend the device with:

```sh
doas devctl suspend pci0:2:0:0
```

## Intel DRM Driver

Current working package:

```text
drm-61-kmod-6.1.128.1501000_9
```

Current loaded modules include:

```text
i915kms.ko
drm.ko
linuxkpi_video.ko
```

After updating to FreeBSD 15.1, the generic DRM path installed `drm-66-kmod`.
With `i915kms` still in `kld_list`, that driver caused a black-screen reboot
loop before the TTY login. The system was recoverable from single-user mode by
mounting the filesystems read/write, getting networking up, removing the bad
driver path from `/etc/rc.conf`, booting back to TTY, and reinstalling:

```sh
doas pkg install -y drm-61-kmod
```

For this laptop, keep `drm-61-kmod` as the known-good Intel graphics driver.
Do not casually switch to `drm-66-kmod`; only test a newer DRM branch when there
is time to recover from single-user mode again.

## `/etc/rc.conf`

Current relevant service/module setup:

```conf
dbus_enable="YES"
seatd_enable="YES"
linux_enable="YES"
powerd_enable="NO"
mx250_suspend_enable="YES"

kld_list="i915kms acpi_video ng_ubt ng_hci ng_l2cap ng_btsocket ext2fs fusefs"

wlans_rtw880="wlan0"
create_args_wlan0="country ES regdomain ETSI"
ifconfig_wlan0="WPA SYNCDHCP"

hcsecd_enable="YES"
bthidd_enable="YES"
tailscaled_enable="YES"
```

Copy-paste setup:

```sh
doas sysrc dbus_enable=YES
doas sysrc seatd_enable=YES
doas sysrc linux_enable=YES
doas sysrc powerd_enable=NO
doas sysrc -x powerd_flags
doas sysrc mx250_suspend_enable=YES
doas sysrc kld_list="i915kms acpi_video ng_ubt ng_hci ng_l2cap ng_btsocket ext2fs fusefs"

doas sysrc wlans_rtw880=wlan0
doas sysrc create_args_wlan0="country ES regdomain ETSI"
doas sysrc ifconfig_wlan0="WPA SYNCDHCP"

doas sysrc hcsecd_enable=YES
doas sysrc bthidd_enable=YES
```

## `/boot/loader.conf`

Current relevant setup:

```conf
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
zfs_load="YES"
cpu_microcode_load="YES"
cpu_microcode_name="/boot/firmware/intel-ucode.bin"
machdep.hwpstate_pkg_ctrl="0"
```

Copy-paste setup:

```sh
doas sysrc -f /boot/loader.conf cpu_microcode_load=YES
doas sysrc -f /boot/loader.conf cpu_microcode_name=/boot/firmware/intel-ucode.bin
doas sysrc -x -f /boot/loader.conf hint.hwpstate_intel.0.disabled
doas sysrc -f /boot/loader.conf machdep.hwpstate_pkg_ctrl=0
```

Reboot after changing loader or kernel-module settings.

## CPU Power Management

The validated configuration keeps `hwpstate_intel` enabled, disables HWP
package control, and does not run `powerd`:

```conf
# /boot/loader.conf
machdep.hwpstate_pkg_ctrl="0"

# /etc/rc.conf
powerd_enable="NO"
```

Expected runtime state:

```sh
sysctl dev.cpufreq.0.freq_driver
sysctl dev.hwpstate_intel | grep '\.epp'
```

```text
dev.cpufreq.0.freq_driver: hwpstate_intel0
```

Each `dev.hwpstate_intel.0.epp` through `dev.hwpstate_intel.7.epp` value should
be `50`.

Set EPP 50 on all eight logical CPUs if needed:

```sh
for cpu in 0 1 2 3 4 5 6 7; do
    doas sysctl "dev.hwpstate_intel.${cpu}.epp=50"
done
```

The old `est0` plus `powerd` workaround is obsolete. HWP package control
performed badly; per-core HWP with `machdep.hwpstate_pkg_ctrl=0` improved
performance substantially. EPP 50 was clearly best in real benchmarks, while
EPP 0 and 100 both performed significantly worse. The QuickShell `performance`
preset selects EPP 0 and starts transient `powerd`, so it is not recommended for
this laptop's validated configuration.

Zen running through Flatpak on FreeBSD improved dramatically with this setup.
The same 1080p24 YouTube test dropped about one frame after more than 1200
frames, comparable to Linux.

## Groups

Current user groups:

```sh
wheel operator video
```

Copy-paste setup:

```sh
doas pw groupmod wheel -m "$USER"
doas pw groupmod operator -m "$USER"
doas pw groupmod video -m "$USER"
```

## Hyprland Monitor

Current laptop monitor rule:

```lua
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x120",
    scale = 1.25,
})
```

This is hardware-specific because `eDP-1`, the offset, and the scale may not make sense on another machine.

The Discord font fix depends on this scale. If the monitor scale changes, update Discord's `--force-device-scale-factor` to match.

## Color / Panel

The internal BOE panel is low-gamut, around 58% sRGB in third-party measurements. Software tweaks can improve tone and contrast, but they cannot make it color accurate.

Panel profile downloaded during setup:

```sh
mkdir -p ~/.local/share/color/icc
fetch -o ~/.local/share/color/icc/BOE082C-Notebookcheck-HP-Pavilion-x360-14.icm \
  https://www.notebookcheck.net/uploads/tx_nbc2/HP_Pavilion_x360_14.icm
```

Hyprland 0.55 has color-management support, but direct ICC loading should be tested before making it persistent. The compositor-level setting that was kept:

```lua
hl.config({
    render = {
        cm_sdr_eotf = "srgb",
    },
})
```

Subjective gamma/temperature testing used `wl-gammarelay-rs`, but it is not a true calibration tool.

## Firefox VAAPI

Install and verify:

```sh
doas pkg install -y libva-intel-media-driver libva-utils
vainfo
```

Expected driver:

```text
Intel iHD driver
```

Useful decode entries:

```text
VAProfileH264High
VAProfileVP9Profile0
VAProfileHEVCMain
```

Firefox profiles on this machine:

```text
~/.config/mozilla/firefox/ogj2q96h.default-release/user.js
~/.config/mozilla/firefox/46kme5aj.default/user.js
```

Prefs applied:

```js
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.av1.enabled", false);
user_pref("gfx.webrender.all", true);
user_pref("widget.dmabuf.force-enabled", true);
```

`media.av1.enabled = false` is important for this iGPU because AV1 is CPU decoded.

## Discord Runtime Override

The stow-managed Discord piece is the desktop launcher:

```text
discord/.local/share/applications/linux-discord.desktop
```

Do not stow the entire Discord profile directory. It contains caches, tokens, cookies, and runtime state.

The one runtime file that matters is:

```text
~/.config/discord/settings.json
```

Known-good contents:

```json
{"SKIP_HOST_UPDATE": true}
```

Protect it from the FreeBSD `linux-discord` wrapper:

```sh
./scripts/setup-discord-runtime.sh
```

To edit it:

```sh
doas chflags noschg ~/.config/discord/settings.json
```

The working Discord rendering setup is:

```lua
hl.config({
    xwayland = {
        force_zero_scaling = true,
    },
})
```

```sh
/usr/local/bin/linux-discord --force-device-scale-factor=1.25
```

Avoid:

```sh
--force-device-scale-factor=0.9
--enable-features=UseOzonePlatform --ozone-platform=wayland
FONTCONFIG_FILE=...
```

Those caused blurry fonts, missing text, or high CPU usage.

## Wallpaper

Current live wallpaper:

```text
~/regueiro-hyprland/wallpapers/japan-background-blured-redish.jpg
```

The autostart line uses `hyprpaper` and the stowed `hyprpaper.conf` points to
the repo-managed wallpaper:

```lua
hl.exec_cmd("hyprpaper")
```

## Suspend / Resume

ACPI reports S3 support:

```text
hw.acpi.suspend_state=S3
hw.acpi.supported_sleep_state="S3 S4 S5"
```

Manual tests with FreeBSD `zzz` froze the machine and required a forced
power-off. The following runtime workarounds were tested and did not fix it:

```sh
doas sysctl hw.acpi.reset_video=1
doas sysctl hw.pci.do_power_nodriver=1
doas sysctl kern.vt.suspendswitch=0
```

QuickShell intentionally hides and blocks Suspend. Hypridle only locks and
turns the display off; automatic full system suspend remains disabled.
