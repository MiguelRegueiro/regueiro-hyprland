# Installer feature selection

Optional desktop features can register package prerequisites and setup actions
here. Feature runtime code lives under `features/`; this directory contains only
installer metadata and orchestration.

Native package names are stored in tab-separated catalogs under
`installer/packages/profiles/`. Each row is an install group and one package
name. `base` is the small Git/Stow bootstrap set; `core`, `connectivity`,
`power`, `audio`, `desktop`, `capture`, `terminal`, `input`, and `runtime` are
groups in the current Hyprland profile. The default profile installs all
groups to preserve existing behavior. Pass `--groups GROUP[,GROUP...]` after
`--profile hyprland` to install selected optional groups; `base` and `core` are
always included. Available groups vary by platform. This is package-group
selection, not the future application feature resolver: package dependencies
and setup actions are still handled by the native package manager or manually.
Use `--interactive` instead of `--groups` for a numbered text prompt. An empty
answer chooses the full recommended set; `none` installs only base and core.
