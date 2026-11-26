#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-mimeclip-supervisor.XXXXXX")
supervisor_pid=
session_pid=
cleanup() {
    if [ -n "$session_pid" ]; then
        kill "$session_pid" 2>/dev/null || true
        wait "$session_pid" 2>/dev/null || true
    fi
    if [ -n "$supervisor_pid" ]; then
        kill -TERM "$supervisor_pid" 2>/dev/null || true
        attempt=0
        while [ "$attempt" -lt 20 ] && kill -0 "$supervisor_pid" 2>/dev/null; do
            sleep 0.1
            attempt=$((attempt + 1))
        done
    fi
    rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

home=$tmp_dir/home
mkdir -p "$home/.local/bin" "$home/.cache"
cat >"$home/.local/bin/triton-mimeclip" <<'EOF'
#!/bin/sh
case "$1" in
    resolve)
        [ "$2" = daemon ] || exit 2
        printf '%s\n' "$FAKE_DAEMON"
        ;;
    client)
        # Model an IPC client that never returns from its health check.
        exec sleep 60
        ;;
    *) exit 2 ;;
esac
EOF
cat >"$tmp_dir/fake-daemon" <<'EOF'
#!/bin/sh
printf 'restart\n' >>"$DAEMON_STARTS"
exit 1
EOF
chmod +x "$home/.local/bin/triton-mimeclip" "$tmp_dir/fake-daemon"

sleep 60 &
session_pid=$!
HOME=$home XDG_CACHE_HOME="$home/.cache" XDG_RUNTIME_DIR= TMPDIR="$tmp_dir" FAKE_DAEMON="$tmp_dir/fake-daemon" \
    DAEMON_STARTS="$tmp_dir/starts" \
    "$repo_dir/desktop/session/start-mimeclip" --session-pid "$session_pid"

lock_dir=$home/.cache/triton-mimeclip/supervisor
if [ ! -d "$lock_dir" ]; then
    echo "MimeClip supervisor did not use the private cache lock directory." >&2
    exit 1
fi
if [ -e "$tmp_dir/triton-mimeclip-$(id -u)" ]; then
    echo "MimeClip created a lock directly under shared TMPDIR." >&2
    exit 1
fi

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ -s "$tmp_dir/starts" ] && [ "$(wc -l <"$tmp_dir/starts")" -ge 2 ]; then
        break
    fi
    sleep 0.1
    attempt=$((attempt + 1))
done
if [ ! -s "$tmp_dir/starts" ] || [ "$(wc -l <"$tmp_dir/starts")" -lt 2 ]; then
    echo "MimeClip supervisor did not restart the crashing daemon." >&2
    exit 1
fi

supervisor_pid=$(cat "$lock_dir/pid")
kill "$session_pid"
wait "$session_pid" 2>/dev/null || true
session_pid=
attempt=0
while [ "$attempt" -lt 50 ] && [ -d "$lock_dir" ]; do
    sleep 0.1
    attempt=$((attempt + 1))
done
if [ -d "$lock_dir" ]; then
    echo "MimeClip supervisor did not stop and clean up after its session ended." >&2
    exit 1
fi
supervisor_pid=

echo "MimeClip supervisor restart, health-check timeout, and session cleanup checks passed."
