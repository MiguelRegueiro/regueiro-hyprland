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
if [ "$simulate" = no ] && [ "$deleting" = no ] && [ "${FAIL_STOW_PACKAGE:-}" = "$last" ]; then
    echo "injected deployment failure at $last" >&2
    exit 19
fi
exec "$TRITON_REAL_STOW" "$@"
EOF
chmod +x "$tmp_dir/bin/stow"

if HOME="$tmp_dir/home" XDG_DATA_HOME= PATH="$tmp_dir/bin:/usr/bin:/bin" \
    TRITON_REAL_STOW="$real_stow" FAIL_STOW_PACKAGE=hypridle \
    "$repo_dir/install.sh" --config-only >"$tmp_dir/install.log" 2>&1; then
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
HOME="$tmp_dir/home" XDG_DATA_HOME= "$repo_dir/install.sh" --config-only >/dev/null 2>&1
if HOME="$tmp_dir/home" XDG_DATA_HOME= PATH="$tmp_dir/bin:/usr/bin:/bin" \
    TRITON_REAL_STOW="$real_stow" FAIL_STOW_PACKAGE=hypridle \
    "$repo_dir/install.sh" --config-only >"$tmp_dir/reinstall.log" 2>&1; then
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

# Exercise the generated FreeBSD bridge ownership and rollback paths using a
# fake FreeBSD uname and compiler; no native helper or hardware is invoked.
freebsd_bin=$tmp_dir/freebsd-bin
freebsd_home=$tmp_dir/freebsd-home
mkdir -p "$freebsd_bin" "$freebsd_home"
cat >"$freebsd_bin/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -s) printf '%s\n' FreeBSD ;;
    -r) printf '%s\n' 15.1-RELEASE ;;
    *) exec /usr/bin/uname "$@" ;;
esac
EOF
cat >"$freebsd_bin/cc" <<'EOF'
#!/bin/sh
output=
while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then shift; output=$1; fi
    shift
done
[ -n "$output" ] || exit 2
printf '#!/bin/sh\nexit 0\n' >"$output"
chmod 0755 "$output"
EOF
chmod +x "$freebsd_bin/uname" "$freebsd_bin/cc"
freebsd_path=$freebsd_bin:/usr/local/bin:/usr/bin:/bin
HOME="$freebsd_home" XDG_DATA_HOME= XDG_STATE_HOME="$freebsd_home/.local/state" \
    PATH="$freebsd_path" "$repo_dir/install.sh" --config-only >"$tmp_dir/freebsd-install.log" 2>&1 || {
        cat "$tmp_dir/freebsd-install.log" >&2
        echo "Mock FreeBSD installation did not complete." >&2
        exit 1
    }
hardware=$freebsd_home/.local/bin/triton-freebsd-hardware
manifest=$freebsd_home/.local/state/triton-desktop/generated/triton-freebsd-hardware.sha256
[ -x "$hardware" ] && [ -f "$manifest" ] || {
    echo "Installer did not record its generated FreeBSD bridge binary." >&2
    exit 1
}
original_hardware_checksum=$(cksum "$hardware" | awk '{ print $1 " " $2 }')
original_groups=$(cat "$freebsd_home/.local/state/triton-desktop/package-groups")
if HOME="$freebsd_home" XDG_DATA_HOME= XDG_STATE_HOME="$freebsd_home/.local/state" \
    PATH="$tmp_dir/bin:$freebsd_path" TRITON_REAL_STOW="$real_stow" \
    FAIL_STOW_PACKAGE=gtk "$repo_dir/install.sh" --config-only >"$tmp_dir/freebsd-failure.log" 2>&1; then
    echo "Mock FreeBSD installer did not surface the injected late Stow failure." >&2
    exit 1
fi
[ "$(cksum "$hardware" | awk '{ print $1 " " $2 }')" = "$original_hardware_checksum" ] || {
    echo "Rollback did not restore the prior generated FreeBSD bridge binary." >&2
    exit 1
}
[ "$(cat "$freebsd_home/.local/state/triton-desktop/package-groups")" = "$original_groups" ] || {
    echo "Failed deployment changed package-group state." >&2
    exit 1
}

cat >"$tmp_dir/bin/pkg" <<'EOF'
#!/bin/sh
case "$1" in info) exit 0 ;; install) exit 0 ;; *) exit 2 ;; esac
EOF
for binary in mimeclip mimeclipd; do
    cat >"$tmp_dir/bin/$binary" <<'EOF'
#!/bin/sh
exit 0
EOF
done
chmod +x "$tmp_dir/bin/pkg" "$tmp_dir/bin/mimeclip" "$tmp_dir/bin/mimeclipd"
if printf 'none\n' | HOME="$freebsd_home" XDG_DATA_HOME= \
    XDG_STATE_HOME="$freebsd_home/.local/state" \
    PATH="$tmp_dir/bin:$freebsd_path" TRITON_REAL_STOW="$real_stow" \
    FAIL_STOW_PACKAGE=gtk "$repo_dir/install.sh" setup >"$tmp_dir/freebsd-selection-failure.log" 2>&1; then
    echo "Installer did not surface the injected failure after changing setup selection." >&2
    exit 1
fi
[ "$(cat "$freebsd_home/.local/state/triton-desktop/package-groups")" = "$original_groups" ] || {
    echo "Failed guided setup changed the previous package-group selection." >&2
    exit 1
}
[ -L "$freebsd_home/.config/fish/config.fish" ] || {
    echo "Failed guided setup did not restore the previously selected Fish config." >&2
    exit 1
}

HOME="$freebsd_home" XDG_STATE_HOME="$freebsd_home/.local/state" \
    "$repo_dir/install.sh" uninstall >/dev/null 2>&1
[ ! -e "$hardware" ] && [ ! -e "$manifest" ] || {
    echo "Uninstaller did not remove its unchanged generated hardware binary." >&2
    exit 1
}

# A binary at the same path without Triton's matching ownership record remains
# user data during install and uninstall.
printf '%s\n' 'user-owned executable' >"$hardware"
if HOME="$freebsd_home" XDG_DATA_HOME= XDG_STATE_HOME="$freebsd_home/.local/state" \
    PATH="$freebsd_path" "$repo_dir/install.sh" --config-only >"$tmp_dir/freebsd-conflict.log" 2>&1; then
    echo "Installer overwrote an untracked user binary at the generated-file path." >&2
    exit 1
fi
HOME="$freebsd_home" XDG_STATE_HOME="$freebsd_home/.local/state" \
    "$repo_dir/install.sh" uninstall >/dev/null 2>&1
[ "$(cat "$hardware")" = 'user-owned executable' ] || {
    echo "Uninstaller removed a user-owned file at the generated-binary path." >&2
    exit 1
}

echo "Installer Stow, package-group, and generated FreeBSD binary rollback/ownership checks passed (FreeBSD build simulated)."
