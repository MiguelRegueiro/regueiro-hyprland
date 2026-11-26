#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-platform-detection.XXXXXX")
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup 0
trap 'exit 1' HUP INT TERM

mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${TRITON_TEST_UNAME:-Linux}"
EOF
chmod +x "$tmp_dir/bin/uname"

for pair in 'Linux linux' 'FreeBSD freebsd' 'NetBSD unknown'; do
    set -- $pair
    actual=$(PATH="$tmp_dir/bin:/usr/bin:/bin" TRITON_TEST_UNAME=$1 \
        "$repo_dir/desktop/scripts/.local/bin/triton-platform")
    if [ "$actual" != "$2" ]; then
        echo "Platform detection mapped $1 to $actual instead of $2." >&2
        exit 1
    fi
done

if ! grep -F 'Quickshell.env("TRITON_PLATFORM")' \
    "$repo_dir/desktop/quickshell/.config/quickshell/services/PlatformService.qml" >/dev/null; then
    echo "PlatformService does not consume the normalized session platform." >&2
    exit 1
fi

echo "Platform detection checks passed."
