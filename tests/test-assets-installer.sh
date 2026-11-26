#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-assets-installer.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

home=$tmp_dir/home
data=$home/data
mkdir -p "$data"
printf '%s\n' 'user-owned path' >"$data/triton-desktop"

if HOME=$home XDG_DATA_HOME=$data "$repo_dir/installer/install-assets.sh" --check >/dev/null 2>&1; then
    echo "Asset preflight accepted a file where the asset directory is required." >&2
    exit 1
fi
if [ -e "$data/fonts" ] || [ -e "$data/icons" ]; then
    echo "Asset preflight created directories while checking for conflicts." >&2
    exit 1
fi

if HOME=$home XDG_DATA_HOME=$data "$repo_dir/installer/install-assets.sh" >/dev/null 2>&1; then
    echo "Asset installer unexpectedly passed a parent-path conflict." >&2
    exit 1
fi
if [ -L "$data/fonts/triton-desktop" ] || [ -L "$data/icons/Bibata-Modern-Classic" ]; then
    echo "Asset installer did not roll back links created before a later failure." >&2
    exit 1
fi
if [ "$(cat "$data/triton-desktop")" != 'user-owned path' ]; then
    echo "Asset installer changed a conflicting user-owned path." >&2
    exit 1
fi

echo "Asset preflight and rollback checks passed."
