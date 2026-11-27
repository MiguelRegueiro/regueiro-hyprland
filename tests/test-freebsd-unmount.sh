#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-freebsd-unmount.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
mkdir -p "$tmp_dir/bin"

cat >"$tmp_dir/bin/id" <<'EOF'
#!/bin/sh
[ "${1:-}" = -u ] || exit 2
printf '0\n'
EOF
cat >"$tmp_dir/bin/mount" <<'EOF'
#!/bin/sh
[ "${1:-}" = -p ] || exit 2
printf '%s\n' "$MOUNT_LINE"
EOF
cat >"$tmp_dir/bin/umount" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$UMOUNT_LOG"
EOF
chmod +x "$tmp_dir/bin/id" "$tmp_dir/bin/mount" "$tmp_dir/bin/umount"

sed "s|^PATH=.*|PATH=$tmp_dir/bin:/usr/bin:/bin|" \
    "$repo_dir/desktop/platforms/freebsd/libexec/triton-privileged" \
    >"$tmp_dir/triton-privileged"
chmod +x "$tmp_dir/triton-privileged"

: >"$tmp_dir/umount.log"
DOAS_USER=tester MOUNT_LINE='/dev/da0p1 /media/tester/USB ufs rw 0 0' \
    UMOUNT_LOG="$tmp_dir/umount.log" \
    "$tmp_dir/triton-privileged" drive unmount /dev/da0p1 /media/tester/USB
[ "$(cat "$tmp_dir/umount.log")" = '/media/tester/USB' ] || {
    echo "Allowed removable-media unmount did not use a normal unmount." >&2
    exit 1
}

if DOAS_USER=tester MOUNT_LINE='/dev/da0p1 /home/other/important ufs rw 0 0' \
    UMOUNT_LOG="$tmp_dir/umount.log" \
    "$tmp_dir/triton-privileged" drive unmount /dev/da0p1 /home/other/important \
    >"$tmp_dir/rejected.log" 2>&1; then
    echo "Privileged helper accepted an unmount outside the invoking user's media directory." >&2
    exit 1
fi
if DOAS_USER=tester MOUNT_LINE='/dev/ada0p1 /media/tester/disk ufs rw 0 0' \
    UMOUNT_LOG="$tmp_dir/umount.log" \
    "$tmp_dir/triton-privileged" drive unmount /dev/ada0p1 /media/tester/disk \
    >"$tmp_dir/rejected-disk.log" 2>&1; then
    echo "Privileged helper accepted an internal-disk unmount." >&2
    exit 1
fi
[ "$(wc -l <"$tmp_dir/umount.log")" -eq 1 ] || {
    echo "Rejected unmount requests reached the unmount command." >&2
    exit 1
}

echo "FreeBSD privileged unmount authorization and normal-unmount behavior passed with mocked mount commands."
