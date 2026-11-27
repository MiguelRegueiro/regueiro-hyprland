#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-mimeclip-supervisor.XXXXXX")
active_supervisor=
active_session=
cleanup() {
    if [ -n "$active_session" ]; then
        kill "$active_session" 2>/dev/null || true
        wait "$active_session" 2>/dev/null || true
    fi
    if [ -n "$active_supervisor" ]; then
        kill -TERM "$active_supervisor" 2>/dev/null || true
        attempt=0
        while [ "$attempt" -lt 80 ] && kill -0 "$active_supervisor" 2>/dev/null; do
            sleep 0.1
            attempt=$((attempt + 1))
        done
    fi
    rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

wait_for_count() {
    file=$1
    count=$2
    attempt=0
    while [ "$attempt" -lt 120 ]; do
        actual=0
        [ ! -f "$file" ] || actual=$(wc -l <"$file")
        [ "$actual" -ge "$count" ] && return 0
        sleep 0.1
        attempt=$((attempt + 1))
    done
    return 1
}

new_home() {
    home=$tmp_dir/$1-home
    mkdir -p "$home/.local/bin" "$home/.cache"
    cat >"$home/.local/bin/triton-mimeclip" <<'EOF'
#!/bin/sh
case "$1" in
    resolve) [ "$2" = daemon ] || exit 2; printf '%s\n' "$FAKE_DAEMON" ;;
    client)
        [ "$2" = ping ] || exit 2
        n=0
        [ ! -f "$PING_COUNT" ] || n=$(cat "$PING_COUNT")
        n=$((n + 1))
        printf '%s\n' "$n" >"$PING_COUNT"
        if [ -f "$PING_HANG" ]; then exec sleep 60; fi
        if [ -f "$PING_ALWAYS_FAIL" ] || [ "$n" -eq 1 ]; then exit 1; fi
        exit 0
        ;;
    *) exit 2 ;;
esac
EOF
    chmod +x "$home/.local/bin/triton-mimeclip"
}

export TRITON_MIMECLIP_HEALTH_INTERVAL=1
export TRITON_MIMECLIP_HEALTH_TIMEOUT=1
export TRITON_MIMECLIP_HEALTH_FAILURES=2
export TRITON_MIMECLIP_STOP_TIMEOUT=1

# A daemon that exits unexpectedly is restarted with bounded backoff.
new_home crash
cat >"$tmp_dir/crash-daemon" <<'EOF'
#!/bin/sh
printf 'start\n' >>"DAEMON_STARTS"
exit 1
EOF
# Expand only the test-owned log location into this fixture script.
sed "s|DAEMON_STARTS|$tmp_dir/crash-starts|" "$tmp_dir/crash-daemon" >"$tmp_dir/crash-daemon.tmp"
mv "$tmp_dir/crash-daemon.tmp" "$tmp_dir/crash-daemon"
chmod +x "$tmp_dir/crash-daemon"
touch "$tmp_dir/crash-fail"
sleep 60 &
active_session=$!
HOME="$tmp_dir/crash-home" XDG_CACHE_HOME="$tmp_dir/crash-home/.cache" \
    XDG_RUNTIME_DIR= TMPDIR="$tmp_dir" FAKE_DAEMON="$tmp_dir/crash-daemon" \
    PING_COUNT="$tmp_dir/crash-pings" PING_ALWAYS_FAIL="$tmp_dir/crash-fail" \
    DAEMON_STARTS="$tmp_dir/crash-starts" \
    "$repo_dir/desktop/session/start-mimeclip" --session-pid "$active_session"
crash_lock=$tmp_dir/crash-home/.cache/triton-mimeclip/supervisor
wait_for_count "$tmp_dir/crash-starts" 2 || {
    echo "MimeClip supervisor did not restart a crashed daemon." >&2
    exit 1
}
active_supervisor=$(cat "$crash_lock/pid")
kill "$active_session"
wait "$active_session" 2>/dev/null || true
active_session=
attempt=0
while [ "$attempt" -lt 50 ] && [ -d "$crash_lock" ]; do sleep 0.1; attempt=$((attempt + 1)); done
[ ! -d "$crash_lock" ] || { echo "Supervisor did not clean up after session exit." >&2; exit 1; }
active_supervisor=

# A live daemon which becomes unresponsive is restarted after consecutive
# bounded health failures. Its TERM handler is deliberately ignored so the
# forced-stop path is exercised too.
new_home hang
cat >"$tmp_dir/hang-daemon" <<'EOF'
#!/bin/sh
printf 'start\n' >>"DAEMON_STARTS"
trap '' TERM
exec sleep 60
EOF
sed "s|DAEMON_STARTS|$tmp_dir/hang-starts|" "$tmp_dir/hang-daemon" >"$tmp_dir/hang-daemon.tmp"
mv "$tmp_dir/hang-daemon.tmp" "$tmp_dir/hang-daemon"
chmod +x "$tmp_dir/hang-daemon"
sleep 60 &
active_session=$!
HOME="$tmp_dir/hang-home" XDG_CACHE_HOME="$tmp_dir/hang-home/.cache" \
    XDG_RUNTIME_DIR= TMPDIR="$tmp_dir" FAKE_DAEMON="$tmp_dir/hang-daemon" \
    PING_COUNT="$tmp_dir/hang-pings" PING_HANG="$tmp_dir/hang-now" \
    PING_ALWAYS_FAIL="$tmp_dir/hang-fail" DAEMON_STARTS="$tmp_dir/hang-starts" \
    "$repo_dir/desktop/session/start-mimeclip" --session-pid "$active_session"
hang_lock=$tmp_dir/hang-home/.cache/triton-mimeclip/supervisor
wait_for_count "$tmp_dir/hang-starts" 1 || { echo "MimeClip daemon did not start." >&2; exit 1; }
active_supervisor=$(cat "$hang_lock/pid")

# A second launcher sees the existing supervisor and must not start a second
# daemon, even while the initial health request reports failure.
HOME="$tmp_dir/hang-home" XDG_CACHE_HOME="$tmp_dir/hang-home/.cache" \
    XDG_RUNTIME_DIR= TMPDIR="$tmp_dir" FAKE_DAEMON="$tmp_dir/hang-daemon" \
    PING_COUNT="$tmp_dir/duplicate-pings" PING_ALWAYS_FAIL="$tmp_dir/duplicate-fail" \
    DAEMON_STARTS="$tmp_dir/hang-starts" \
    "$repo_dir/desktop/session/start-mimeclip" --session-pid "$active_session"
sleep 0.2
[ "$(wc -l <"$tmp_dir/hang-starts")" -eq 1 ] || {
    echo "A duplicate MimeClip supervisor started a second daemon." >&2
    exit 1
}

touch "$tmp_dir/hang-now"
wait_for_count "$tmp_dir/hang-starts" 2 || {
    echo "MimeClip supervisor did not recover an unresponsive daemon." >&2
    exit 1
}
kill "$active_session"
wait "$active_session" 2>/dev/null || true
active_session=
attempt=0
while [ "$attempt" -lt 80 ] && [ -d "$hang_lock" ]; do sleep 0.1; attempt=$((attempt + 1)); done
[ ! -d "$hang_lock" ] || { echo "Supervisor did not stop after session shutdown." >&2; exit 1; }
active_supervisor=

echo "MimeClip crash recovery, hung-daemon recovery, bounded shutdown, duplicate prevention, and session cleanup checks passed."
