#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-mimeclip-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

mkdir -p "$tmp_dir/home/.cargo/bin" "$tmp_dir/usr-local/bin" "$tmp_dir/path-bin"
for dir in "$tmp_dir/home/.cargo/bin" "$tmp_dir/usr-local/bin" "$tmp_dir/path-bin"; do
    for command in mimeclip mimeclipd; do
        cat >"$dir/$command" <<'EOF'
#!/bin/sh
printf '%s\n' "$0:$*"
EOF
        chmod +x "$dir/$command"
    done
done

resolver=$repo_dir/desktop/scripts/.local/bin/triton-mimeclip
resolved=$(HOME="$tmp_dir/home" TRITON_MIMECLIP_SYSTEM_BIN="$tmp_dir/usr-local/bin" PATH="$tmp_dir/path-bin:/usr/bin:/bin" \
    "$resolver" resolve daemon)
if [ "$resolved" != "$tmp_dir/home/.cargo/bin/mimeclipd" ]; then
    echo "Resolver did not prefer the paired Cargo installation: $resolved" >&2
    exit 1
fi

rm "$tmp_dir/home/.cargo/bin/mimeclipd"
resolved=$(HOME="$tmp_dir/home" TRITON_MIMECLIP_SYSTEM_BIN="$tmp_dir/usr-local/bin" PATH="$tmp_dir/path-bin:/usr/bin:/bin" \
    "$resolver" resolve client)
if [ "$resolved" != "$tmp_dir/usr-local/bin/mimeclip" ]; then
    echo "Resolver did not prefer a complete /usr/local installation: $resolved" >&2
    exit 1
fi

output=$(HOME="$tmp_dir/home" TRITON_MIMECLIP_SYSTEM_BIN="$tmp_dir/usr-local/bin" PATH="$tmp_dir/path-bin:/usr/bin:/bin" \
    "$resolver" client ping)
if [ "$output" != "$tmp_dir/usr-local/bin/mimeclip:ping" ]; then
    echo "Client execution did not use the shared resolver: $output" >&2
    exit 1
fi

echo "MimeClip resolver checks passed."
