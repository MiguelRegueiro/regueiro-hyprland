#!/usr/bin/env bash
set -euo pipefail

# Keep the application itself in its own repository. This dotfiles helper
# installs it into ~/.local/bin and makes the Hyprland autostart entry usable.
repository="${TRITON_CONNECT_DIR:-$HOME/triton-connect}"
installer="$repository/desktop-client/app/scripts/install-local.sh"

if [[ ! -e "$repository" ]]; then
  git clone https://github.com/MiguelRegueiro/triton-connect.git "$repository"
elif [[ -d "$repository/.git" ]]; then
  git -C "$repository" pull --ff-only
else
  printf 'Triton Connect path is not a Git checkout: %s\n' "$repository" >&2
  exit 1
fi

if [[ ! -x "$installer" ]]; then
  printf 'Triton Connect installer not found at %s\n' "$installer" >&2
  exit 1
fi

exec "$installer"
