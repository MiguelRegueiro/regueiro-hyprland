#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-update-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/bin" "$tmp_dir/home"
cat >"$tmp_dir/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_PLATFORM:-Linux}"
EOF
cat >"$tmp_dir/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] || exit 2
printf '%s\n' 1000
EOF
cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$CALL_LOG"
EOF
chmod +x "$tmp_dir/bin/uname" "$tmp_dir/bin/id" "$tmp_dir/bin/sudo"

printf 'ID=cachyos\nID_LIKE="arch"\n' >"$tmp_dir/arch-release"
: >"$tmp_dir/calls"
HOME=$tmp_dir/home CALL_LOG=$tmp_dir/calls PATH="$tmp_dir/bin" \
    TRITON_OS_RELEASE_FILE=$tmp_dir/arch-release "$repo_dir/desktop/scripts/.local/bin/triton-update"
if [ "$(cat "$tmp_dir/calls")" != 'sudo pacman -Syu' ]; then
    echo "Arch update did not use pacman safely when paru was unavailable." >&2
    cat "$tmp_dir/calls" >&2
    exit 1
fi

check_update() {
    platform=$1
    release=$2
    expected=$3
    : >"$tmp_dir/calls"
    HOME=$tmp_dir/home CALL_LOG=$tmp_dir/calls PATH="$tmp_dir/bin" \
        FAKE_PLATFORM=$platform TRITON_OS_RELEASE_FILE=$release \
        "$repo_dir/desktop/scripts/.local/bin/triton-update"
    if [ "$(cat "$tmp_dir/calls")" != "$expected" ]; then
        echo "Updater selected the wrong command for $platform / $release." >&2
        cat "$tmp_dir/calls" >&2
        exit 1
    fi
}

printf 'ID=fedora\n' >"$tmp_dir/fedora-release"
check_update Linux "$tmp_dir/fedora-release" 'sudo dnf upgrade --refresh -y'
printf 'ID=debian\n' >"$tmp_dir/debian-release"
check_update Linux "$tmp_dir/debian-release" 'sudo apt update
sudo apt full-upgrade -y'
printf 'ID=void\n' >"$tmp_dir/void-release"
check_update Linux "$tmp_dir/void-release" 'sudo xbps-install -Su'
check_update FreeBSD "$tmp_dir/arch-release" 'sudo pkg upgrade -y'

printf 'ID=unsupported\n' >"$tmp_dir/unsupported-release"
: >"$tmp_dir/calls"
if HOME=$tmp_dir/home CALL_LOG=$tmp_dir/calls PATH="$tmp_dir/bin" \
    TRITON_OS_RELEASE_FILE=$tmp_dir/unsupported-release \
    "$repo_dir/desktop/scripts/.local/bin/triton-update" >"$tmp_dir/error.log" 2>&1; then
    echo "Updater treated an unsupported distribution as Arch." >&2
    exit 1
fi
if [ -s "$tmp_dir/calls" ] || ! grep -F 'Unsupported Linux distribution' "$tmp_dir/error.log" >/dev/null; then
    echo "Updater did not fail closed on an unsupported distribution." >&2
    cat "$tmp_dir/error.log" >&2
    exit 1
fi

echo "Distribution-aware updater checks passed."
