#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/triton-session-cleanup.XXXXXX")
cleanup() {
    if [ -n "${monitor_pid:-}" ]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    if [ -n "${compositor_pid:-}" ]; then
        kill "$compositor_pid" 2>/dev/null || true
        wait "$compositor_pid" 2>/dev/null || true
    fi
    rm -rf "$tmp_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

mkdir -p "$tmp_dir/home/.local/bin"
cat >"$tmp_dir/home/.local/bin/triton-linux-service" <<'EOF'
#!/bin/sh
if [ "$1" = user ] && [ "$2" = cat ]; then
    case "$3" in
        xdg-desktop-portal.service|xdg-desktop-portal-gtk.service|hyprpolkitagent.service) exit 0 ;;
        *) exit 1 ;;
    esac
fi
if [ "$1" = user ] && [ "$2" = stop ]; then
    shift 2
    printf '%s\n' "$*" >"$SERVICE_STOP_LOG"
    exit 0
fi
exit 2
EOF
chmod +x "$tmp_dir/home/.local/bin/triton-linux-service"

sleep 30 &
compositor_pid=$!
HOME="$tmp_dir/home" SERVICE_STOP_LOG="$tmp_dir/stopped" \
    "$repo_dir/desktop/platforms/linux/.local/bin/triton-linux-session-cleanup" "$compositor_pid" &
monitor_pid=$!
sleep 0.1
kill "$compositor_pid"
wait "$compositor_pid" 2>/dev/null || true
compositor_pid=
wait "$monitor_pid"
monitor_pid=

expected='xdg-desktop-portal.service xdg-desktop-portal-gtk.service hyprpolkitagent.service'
if [ "$(cat "$tmp_dir/stopped")" != "$expected" ]; then
    echo "Session cleanup did not stop the expected services." >&2
    cat "$tmp_dir/stopped" >&2
    exit 1
fi

echo "Linux session cleanup check passed."
