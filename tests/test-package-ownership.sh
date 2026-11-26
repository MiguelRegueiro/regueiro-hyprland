#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-package-ownership.XXXXXX")
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

mkdir -p "$tmp_dir/bin" "$tmp_dir/home" "$tmp_dir/state"
printf '%s\n' stow >"$tmp_dir/installed"
cat >"$tmp_dir/bin/pacman" <<'EOF'
#!/bin/sh
if [ "${1:-}" = -Qq ]; then
    grep -Fx "$2" "$TRITON_TEST_INSTALLED" >/dev/null 2>&1
    exit $?
fi
if [ "${1:-}" = -S ] && [ "${2:-}" = --needed ]; then
    shift 2
    for package do
        printf '%s\n' "$package" >>"$TRITON_TEST_INSTALLED"
    done
    exit "${TRITON_TEST_INSTALL_STATUS:-0}"
fi
if [ "${1:-}" = -R ] && [ "${2:-}" = -- ]; then
    shift 2
    installed_tmp=$TRITON_TEST_INSTALLED.tmp
    for package do
        awk -v package="$package" '$0 != package' "$TRITON_TEST_INSTALLED" >"$installed_tmp"
        mv "$installed_tmp" "$TRITON_TEST_INSTALLED"
    done
    exit 0
fi
echo "Unexpected pacman arguments: $*" >&2
exit 2
EOF
cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/bin/sh
exec "$@"
EOF
chmod +x "$tmp_dir/bin/pacman" "$tmp_dir/bin/sudo"

HOME=$tmp_dir/home \
PATH="$tmp_dir/bin:/usr/bin:/bin" \
TRITON_PACKAGE_STATE_DIR=$tmp_dir/state \
TRITON_TEST_INSTALLED=$tmp_dir/installed \
sh -c '. "$1"; tracked_install arch stow git triton-test-package' sh "$repo_dir/installer/packages/root.sh"

manifest=$tmp_dir/state/arch.list
if ! grep -Fx git "$manifest" >/dev/null || \
    ! grep -Fx triton-test-package "$manifest" >/dev/null || \
    grep -Fx stow "$manifest" >/dev/null; then
    echo "Package ownership manifest did not record only newly installed explicit packages." >&2
    cat "$manifest" >&2
    exit 1
fi

HOME=$tmp_dir/home \
PATH="$tmp_dir/bin:/usr/bin:/bin" \
TRITON_PACKAGE_STATE_DIR=$tmp_dir/state \
TRITON_TEST_INSTALLED=$tmp_dir/installed \
sh -c '. "$1"; tracked_install arch stow git triton-test-package' sh "$repo_dir/installer/packages/root.sh"
if [ "$(wc -l <"$manifest")" -ne 2 ]; then
    echo "Repeated package installation duplicated manifest entries." >&2
    cat "$manifest" >&2
    exit 1
fi

if HOME=$tmp_dir/home \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    TRITON_PACKAGE_STATE_DIR=$tmp_dir/state \
    TRITON_TEST_INSTALLED=$tmp_dir/installed \
    TRITON_TEST_INSTALL_STATUS=42 \
    sh -c '. "$1"; tracked_install arch stow partial-package' sh "$repo_dir/installer/packages/root.sh"; then
    echo "Package tracking test failed to preserve the package-manager failure status." >&2
    exit 1
fi
if ! grep -Fx partial-package "$manifest" >/dev/null; then
    echo "Partially successful package transaction was not recorded." >&2
    cat "$manifest" >&2
    exit 1
fi

printf '%s\n' 'keep' |
    HOME=$tmp_dir/home TRITON_PACKAGE_STATE_DIR=$tmp_dir/state \
    PATH="$tmp_dir/bin:/usr/bin:/bin" TRITON_TEST_INSTALLED=$tmp_dir/installed \
    "$repo_dir/install.sh" uninstall --packages >/dev/null
if [ ! -f "$manifest" ] || ! grep -Fx git "$tmp_dir/installed" >/dev/null; then
    echo "Declining package removal changed the ownership record or installed set." >&2
    exit 1
fi

printf '%s\n' remove |
    HOME=$tmp_dir/home TRITON_PACKAGE_STATE_DIR=$tmp_dir/state \
    PATH="$tmp_dir/bin:/usr/bin:/bin" TRITON_TEST_INSTALLED=$tmp_dir/installed \
    "$repo_dir/install.sh" uninstall --packages >/dev/null
if [ -e "$manifest" ] || grep -Fx git "$tmp_dir/installed" >/dev/null || \
    grep -Fx triton-test-package "$tmp_dir/installed" >/dev/null || \
    grep -Fx partial-package "$tmp_dir/installed" >/dev/null || \
    ! grep -Fx stow "$tmp_dir/installed" >/dev/null; then
    echo "Confirmed removal did not remove only packages recorded as Triton-owned." >&2
    cat "$tmp_dir/installed" >&2
    exit 1
fi

echo "Package ownership tracking checks passed."
