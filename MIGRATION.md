# Triton Desktop migration roadmap

Each stage should leave the current Linux/Hyprland desktop working. Keep the
FreeBSD branch intact and port useful services into this shared UI in small,
reviewable changes. Do not merge the old FreeBSD UI wholesale.

## 01 — Rename and establish the structure

- [x] Rename the repository to `triton-desktop`.
- [x] Update the README and the primary project references.
- [x] Separate desktop, compositor, platform, feature, and user-config areas.
- [x] Apply and confirm the controlled Stow-link migration on the live Linux install.

## 02 — Remove Hyprland assumptions from shared code

- [x] Create `CompositorService`.
- [x] Refactor `WorkspaceStrip` and `NotificationStore`.
- [x] Move shared session and feature launchers outside `~/.config/hypr/scripts`; retain compatibility shims for existing Hyprland calls.
- [x] Isolate window rules, keybindings, and display commands under `compositors/hyprland`.

## 03 — Separate Linux-specific services

- [x] Introduce platform and capability detection.
- [x] Isolate networking, battery, brightness, and power implementations.
- [x] Remove unconditional Linux-only QML imports and direct Linux command/path use from shared UI.
- [x] Isolate systemd-specific service management.

Progress: `PlatformService` detects Linux/FreeBSD and advertises implemented
adapters. Quickshell QML backends live under the service adapters that load
them. OS command helpers and the FreeBSD hardware bridge live under
`desktop/platforms/{linux,freebsd}/`. Fcitx, power, systemd session-service,
external-drive, and system-statistics operations use OS-specific commands
through the shared desktop services. Linux-only QML imports and direct Linux
paths and commands have been removed from shared UI. Other operating systems
report unavailable capabilities until their adapters are implemented in Stage
04; this does not claim Linux backends already work on FreeBSD.

## 04 — Port FreeBSD functionality incrementally

- [x] Port the native hardware bridge.
- [x] Port battery, Wi-Fi, Bluetooth, and power services.
- [x] Port external-drive and system-statistics support.
- [ ] Validate audio, portals, authentication, and suspend.

Progress: The native FreeBSD battery adapter is ported behind the shared
battery service, using `apm` and `acpiconf`. The branch's persistent brightness
and OSS mixer bridge is now in `desktop/platforms/freebsd/`; the installer
builds it on FreeBSD and the shared brightness service selects its adapter.
The FreeBSD network status and Ethernet-toggle backend now feeds the shared
network service. The Wi-Fi scan, saved-profile, connect, and forget commands
are also adapted to the shared Wi-Fi page model. These FreeBSD paths have only
been syntax-checked on Linux and still need a build and hardware validation on
the preserved FreeBSD machine. The FreeBSD Bluetooth status, power, device
connection, and settings commands now use the shared Bluetooth page.
CPU, memory, swap, and process statistics are normalized by a FreeBSD helper
for the shared system-details service. External-drive discovery parses the
FreeBSD UDisks dump, while mount and eject operations use FreeBSD platform
helpers. The shared power-profile selector now uses the FreeBSD `powerd` and
EPP helper. Shared reboot and poweroff actions now resolve through the
platform service; FreeBSD uses a dedicated non-interactive `doas shutdown`
adapter. Linux-only idle, lock, suspend-timer, and power-button policy controls
are now explicitly unavailable on FreeBSD until that backend is ported, and
Suspend is omitted from its power menus until a FreeBSD suspend adapter is
validated.

## 05 — Make the session reliable

- [ ] Unify startup and shutdown.
- [x] Fix MimeClip client/daemon resolution and avoid competing session supervisors.
- [ ] Implement restart and health checks.
- [ ] Make optional services capability-aware.

Progress: QuickShell, Triton TTS, powerctl, Fcitx, `wl-clip-persist`, and
Blueman are tied to the active Hyprland session. `powerctl` cleans up stale
daemons from previous sessions; MimeClip uses a session supervisor when one is
not already owned by a systemd user service. That existing user service may
persist across logins and reconnect to Wayland. Elio's file-manager integration
and Triton Connect still need an explicit shutdown policy, and restart/health
behavior is not yet unified across all long-running services.

## 06 — Implement the installer

- [x] Detect OS and distribution automatically for the bootstrap package command.
- [ ] Install native dependencies.
- [ ] Add optional application and feature selection.
- [ ] Back up existing configuration and deploy Stow packages safely.
- [x] Test repeated installations and reject Stow conflicts before changing files.

Progress: `./install.sh packages` detects FreeBSD or reads Linux `os-release`
and selects the matching package manager. It installs only Git and GNU Stow
(plus explicitly requested package names); runtime desktop dependencies and
optional feature selection remain manual. Tests use fake package managers and
temporary home directories, so they do not install packages on the host.

An explicit `./install.sh packages --profile hyprland` profile now installs the
current Hyprland runtime package set on Arch/CachyOS only. The default install
still only deploys configuration, and the profile does not enable services.
Fedora's official builds for the compositor, idle daemon, and wallpaper daemon
do not currently line up with current Fedora releases, so the profile refuses
there without installing packages. Other distribution profiles remain
unimplemented until their package sets and service setup have been verified.

## 07 — Implement stable releases and updates

- [ ] Add versioned releases and a stable channel.
- [ ] Add update and rollback commands.
- [ ] Preserve local settings.
- [ ] Add desktop diagnostics.

## 08 — Integrate TritonBSD

- [ ] Pin a tested desktop release.
- [ ] Integrate with `triton-install`.
- [ ] Bundle distribution-default applications.
- [ ] Configure native and Flatpak browsers.

## 09 — Add Niri support

- [ ] Implement the Niri IPC backend.
- [ ] Port keybindings and floating-window rules.
- [ ] Implement output management and workspace handling.
- [ ] Validate locking, portals, and screen sharing.

## FreeBSD components to preserve

Bring backend functionality into the current desktop while keeping the modern
QuickShell UI. Do not bring the old bar, launcher, or quick settings forward.

| Existing FreeBSD component | Migration target |
| --- | --- |
| `FreeBsdHardwareService.qml` | Native FreeBSD platform hardware adapter |
| Battery service | FreeBSD battery backend behind the shared battery contract |
| Brightness service | FreeBSD backend for the shared brightness UI |
| Network and Wi-Fi services | Native networking backend |
| External drives service | FreeBSD mount and device backend |
| System details service | Native system-statistics adapter |
| Audio service | Share the PipeWire path where supported |
| `rc.d/mx250_suspend` | Optional hardware workaround, documented and gated |
| `setup-freebsd-realtime.sh` | Optional FreeBSD performance feature |
| `pkg/pkg.conf` | Review separately as an OS-level setting |
| Clipboard service | Use the shared MimeClip client/daemon contract |

Keep the existing FreeBSD branch available until this roadmap is validated on
real FreeBSD hardware.

## Installer direction

The eventual standalone install should stay simple:

```sh
git clone https://github.com/MiguelRegueiro/triton-desktop
cd triton-desktop
./install.sh
```

The root script remains the only public entry point. Internal installer code
should resolve dependencies from declarative feature selections, detect the
platform, back up conflicting configuration, and make repeated runs safe.
Selecting a feature such as dictation should bring its runtime dependencies and
the platform-appropriate audio/acceleration backend automatically.
