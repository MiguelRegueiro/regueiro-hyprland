#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-wallpaper-state.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

home=$tmp_dir/home
state=$tmp_dir/state
mkdir -p "$home/.local/bin" "$state/regueiro-hyprland"
printf '%s\n' "$home/regueiro-hyprland/wallpapers/wallpaper5.png" \
    >"$state/regueiro-hyprland/wallpaper"
cat >"$home/.local/bin/hyprctl" <<'EOF'
#!/bin/sh
if [ "${1:-}" = hyprpaper ] && [ "${2:-}" = listactive ]; then
    exit 0
fi
printf '%s\n' "$*" >>"$HYPRCTL_LOG"
EOF
chmod +x "$home/.local/bin/hyprctl"

HOME=$home XDG_STATE_HOME=$state PATH="$home/.local/bin:/usr/bin:/bin" \
    HYPRCTL_LOG=$tmp_dir/hyprctl.log \
    "$repo_dir/compositors/hyprland/hypr/.config/hypr/scripts/set-wallpaper" restore

expected=$(realpath "$repo_dir/desktop/assets/wallpapers/wallpaper5.png")
if [ "$(cat "$state/triton-desktop/wallpaper")" != "$expected" ]; then
    echo "Wallpaper restore did not migrate the saved legacy selection." >&2
    exit 1
fi
if [ "$(cat "$state/regueiro-hyprland/wallpaper")" != "$home/regueiro-hyprland/wallpapers/wallpaper5.png" ]; then
    echo "Wallpaper migration modified the legacy state file." >&2
    exit 1
fi
if ! grep -F "$expected" "$tmp_dir/hyprctl.log" >/dev/null; then
    echo "Wallpaper restore did not apply the migrated image." >&2
    exit 1
fi

echo "Wallpaper state migration check passed."
