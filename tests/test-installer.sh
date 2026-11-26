#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-installer-test.XXXXXX")
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

if ! command -v stow >/dev/null 2>&1; then
    echo "GNU Stow is required for installer tests." >&2
    exit 77
fi

fresh_home=$tmp_dir/fresh-home
mkdir -p "$fresh_home"
HOME=$fresh_home "$repo_dir/install.sh" >/dev/null
HOME=$fresh_home "$repo_dir/install.sh" >/dev/null

for relative in \
    .config/hypr/scripts/run-session-command \
    .config/hypr/scripts/start-session-quickshell \
    .config/hypr/scripts/start-session-services \
    .config/hypr/scripts/powerctl \
    .local/bin/triton-run-session-command \
    .local/bin/triton-connect-session \
    .local/bin/triton-linux-session-cleanup
do
    target=$fresh_home/$relative
    if [ ! -L "$target" ] || [ ! -e "$target" ]; then
        echo "Expected a valid Stow link at $target" >&2
        exit 1
    fi
done

conflict_home=$tmp_dir/conflict-home
conflict=$conflict_home/.config/hypr/scripts/powerctl
mkdir -p "$(dirname -- "$conflict")"
printf '%s\n' 'user-owned file' >"$conflict"
if HOME=$conflict_home "$repo_dir/install.sh" >"$tmp_dir/conflict.log" 2>&1; then
    echo "Installer unexpectedly accepted a conflicting user file." >&2
    exit 1
fi
if [ "$(cat "$conflict")" != 'user-owned file' ] || [ -e "$conflict_home/.config/quickshell" ]; then
    echo "Installer changed user data or partially installed before reporting a conflict." >&2
    exit 1
fi

"$repo_dir/tests/test-package-detection.sh"

echo "Installer fresh, repeat, and conflict checks passed."
