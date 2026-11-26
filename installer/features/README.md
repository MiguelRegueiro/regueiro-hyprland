# Installer feature selection

Optional desktop features can register package prerequisites and setup actions
here. Feature runtime code lives under `features/`; this directory contains only
installer metadata and orchestration.

Native package names are stored in tab-separated catalogs under
`installer/packages/profiles/`. Each row is an install group and one package
name. `base` is the small Git/Stow bootstrap set; `core`, `connectivity`,
`connectivity`, `power`, `audio`, `capture`, `terminal`, `input`, `runtime`,
`editor`, and `flatpak` are optional groups where available. The default
package profile installs all groups to preserve existing behavior. Pass
`--groups GROUP[,GROUP...]` after `--profile hyprland` to select optional
packages; `base` and `core` are always included. Available groups vary by
platform. `./install.sh setup` uses the same selection to deploy the matching
optional configurations, so selecting `none` does not link Fish, Fcitx, Neovim,
or Flatpak settings. The lower-level `./install.sh packages` command installs
packages only. This is still package-group selection, not the future declarative
application feature resolver: dependencies and setup actions are handled by the
native package manager or manually.

Use `--interactive` instead of `--groups` for a numbered text prompt. An empty
answer chooses the full recommended set; `none` installs only base and core.
