#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
real_stow=$(command -v stow || true)
[ -n "$real_stow" ] || { echo "GNU Stow is required for rollback checks." >&2; exit 77; }
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-rollback-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.local/share"
cat >"$tmp_dir/bin/stow" <<'EOF'
#!/bin/sh
simulate=no
deleting=no
last=
for arg do
    last=$arg
    case "$arg" in --simulate) simulate=yes ;; --delete) deleting=yes ;; esac
done
if [ "$simulate" = no ] && [ "$deleting" = no ] && [ "$last" = hypridle ]; then
    echo "injected deployment failure" >&2
    exit 19
fi
exec "$TRITON_REAL_STOW" "$@"
EOF
chmod +x "$tmp_dir/bin/stow"

if HOME="$tmp_dir/home" XDG_DATA_HOME= PATH="$tmp_dir/bin:/usr/bin:/bin" \
    TRITON_REAL_STOW="$real_stow" "$repo_dir/install.sh" >"$tmp_dir/install.log" 2>&1; then
    echo "Installer did not surface the injected Stow failure." >&2
    exit 1
fi
if [ -e "$tmp_dir/home/.config/hypr/scripts/displayctl" ] || \
    [ -e "$tmp_dir/home/.config/hypr/scripts/powerctl" ]; then
    echo "Rollback left newly created compositor links after deployment failed." >&2
    find "$tmp_dir/home/.config/hypr" -maxdepth 3 -type l -print >&2 2>/dev/null || true
    exit 1
fi

# Start from a working installation; a later failed deployment must restore
# its already-active Hyprland links instead of deleting them.
HOME="$tmp_dir/home" XDG_DATA_HOME= "$repo_dir/install.sh" >/dev/null 2>&1
if HOME="$tmp_dir/home" XDG_DATA_HOME= PATH="$tmp_dir/bin:/usr/bin:/bin" \
    TRITON_REAL_STOW="$real_stow" "$repo_dir/install.sh" >"$tmp_dir/reinstall.log" 2>&1; then
    echo "Second installer run did not exercise the injected failure." >&2
    exit 1
fi
for relative in .config/hypr/scripts/displayctl .config/hypr/scripts/powerctl; do
    if [ ! -L "$tmp_dir/home/$relative" ] || [ ! -e "$tmp_dir/home/$relative" ]; then
        echo "Rollback failed to restore a previously installed link: $relative" >&2
        cat "$tmp_dir/reinstall.log" >&2
        exit 1
    fi
done

echo "Installer Stow rollback checks passed."
