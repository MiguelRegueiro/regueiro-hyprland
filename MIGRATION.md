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

- [ ] Introduce platform and capability detection.
- [ ] Isolate networking, battery, brightness, and power implementations.
- [ ] Remove unconditional Linux-only QML imports.
- [ ] Isolate systemd-specific service management.

Progress: `PlatformService` detects Linux/FreeBSD and advertises implemented
adapters. Linux networking, brightness, battery, and power-profile
implementations now live under `platforms/linux/` and load through shared
service contracts. The systemd power actions used by Hyprland idle policy now
go through a Linux platform command. The installer deploys those backends.
Hyprland idle policy, systemd portal/session management, and any remaining
platform-only imports still need to be separated; the stage remains open.

## 04 — Port FreeBSD functionality incrementally

- [ ] Port the native hardware bridge.
- [ ] Port battery, Wi-Fi, Bluetooth, and power services.
- [ ] Port external-drive and system-statistics support.
- [ ] Validate audio, portals, authentication, and suspend.

## 05 — Make the session reliable

- [ ] Unify startup and shutdown.
- [ ] Fix MimeClip client/daemon resolution.
- [ ] Implement restart and health checks.
- [ ] Make optional services capability-aware.

## 06 — Implement the installer

- [ ] Detect OS and distribution automatically.
- [ ] Install native dependencies.
- [ ] Add optional application and feature selection.
- [ ] Back up existing configuration and deploy Stow packages safely.
- [ ] Test repeated installations.

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
