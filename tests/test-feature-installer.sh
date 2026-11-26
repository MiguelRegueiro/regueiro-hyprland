#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-feature-install.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/cargo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$CARGO_CALL_LOG"
mkdir -p "$HOME/.cargo/bin"
for binary in mimeclip mimeclipd; do
    printf '#!/bin/sh\nexit 0\n' >"$HOME/.cargo/bin/$binary"
    chmod +x "$HOME/.cargo/bin/$binary"
done
EOF
chmod +x "$tmp_dir/bin/cargo"
mkdir -p "$tmp_dir/home"
: >"$tmp_dir/cargo.log"
HOME=$tmp_dir/home CARGO_CALL_LOG=$tmp_dir/cargo.log PATH="$tmp_dir/bin:/usr/bin:/bin" \
    "$repo_dir/installer/features/install-mimeclip.sh" >/dev/null

expected='install --git https://github.com/MiguelRegueiro/mimeclip --rev 7f64fc05332abfc52ffee0b2dca79e27da5711c2 --locked --bins'
if ! grep -Fx "$expected" "$tmp_dir/cargo.log" >/dev/null; then
    echo "MimeClip installer did not use its pinned, locked source revision." >&2
    cat "$tmp_dir/cargo.log" >&2
    exit 1
fi

HOME=$tmp_dir/home CARGO_CALL_LOG=$tmp_dir/cargo.log PATH="$tmp_dir/home/.cargo/bin:$tmp_dir/bin:/usr/bin:/bin" \
    "$repo_dir/installer/features/install-mimeclip.sh" >/dev/null
if [ "$(wc -l <"$tmp_dir/cargo.log")" -ne 1 ]; then
    echo "MimeClip installer rebuilt binaries that were already available." >&2
    exit 1
fi

echo "Pinned MimeClip installer checks passed."
