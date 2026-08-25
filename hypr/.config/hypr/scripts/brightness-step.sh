#!/bin/sh

case "$1" in
  up|down)
    direction="$1"
    ;;
  *)
    exit 64
    ;;
esac

run_lockdir="${TMPDIR:-/tmp}/regueiro-brightness-step.lock"
state_lockdir="${TMPDIR:-/tmp}/regueiro-brightness-step.state.lock"
qs_bin="${QS_BIN:-$(command -v qs 2>/dev/null || true)}"
state_file="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/regueiro-brightness-step.state"
min_step_ms=90
opposite_guard_ms=450

run_locked=0
state_locked=0

cleanup_run() {
    if [ "$run_locked" -eq 1 ]; then
        rmdir "$run_lockdir"
        run_locked=0
    fi
}

cleanup_state() {
    if [ "$state_locked" -eq 1 ]; then
        rmdir "$state_lockdir"
        state_locked=0
    fi
}

cleanup_all() {
    cleanup_state
    cleanup_run
}

lock_state() {
    tries=0
    while ! mkdir "$state_lockdir" 2>/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -ge 20 ] && return 1
        sleep 0.01
    done
    state_locked=1
    return 0
}

trap 'cleanup_all' EXIT HUP INT TERM

now_ms=$(($(date +%s%N) / 1000000))
last_direction=
last_seen_ms=0
last_step_ms=0

lock_state || exit 0
if read -r last_direction last_seen_ms last_step_ms < "$state_file" 2>/dev/null; then
    case "$last_seen_ms" in
      ''|*[!0-9]*)
        last_seen_ms=0
        ;;
    esac
    case "$last_step_ms" in
      ''|*[!0-9]*)
        last_step_ms=0
        ;;
    esac
fi

if [ "$last_direction" = "$direction" ]; then
    age_ms=$((now_ms - last_step_ms))
    # A newer helper reached the state lock first; discard this stale event.
    [ "$age_ms" -lt 0 ] && age_ms=0
    if [ "$age_ms" -lt "$min_step_ms" ]; then
        printf '%s %s %s\n' "$direction" "$now_ms" "$last_step_ms" > "$state_file"
        cleanup_state
        exit 0
    fi
elif [ -n "$last_direction" ]; then
    age_ms=$((now_ms - last_seen_ms))
    # Never let an out-of-order opposite event bypass the direction guard.
    [ "$age_ms" -lt 0 ] && age_ms=0
    if [ "$age_ms" -lt "$opposite_guard_ms" ]; then
        cleanup_state
        exit 0
    fi
fi
printf '%s %s %s\n' "$direction" "$now_ms" "$now_ms" > "$state_file"
cleanup_state

if ! mkdir "$run_lockdir" 2>/dev/null; then
    exit 0
fi
run_locked=1

current=$(/usr/bin/backlight -q 2>/dev/null | awk '
    /^[0-9]+$/ {
        print int($1 + 0.5)
        exit
    }
    /brightness:[[:space:]]*[0-9]+/ {
        sub(/^.*brightness:[[:space:]]*/, "")
        print int($1 + 0.5)
        exit
    }
')

case "$current" in
  ''|*[!0-9]*)
    exit 65
    ;;
esac

stops="2 5 10 15 20 25 30 35 40 45 50 55 60 70 80 90 100"
reverse_stops="100 90 80 70 60 55 50 45 40 35 30 25 20 15 10 5 2"
target="$current"

case "$direction" in
  up)
    for stop in $stops; do
        if [ "$stop" -gt "$target" ]; then
            target="$stop"
            break
        fi
    done
    ;;
  down)
    for stop in $reverse_stops; do
        if [ "$stop" -lt "$target" ]; then
            target="$stop"
            break
        fi
    done
    ;;
esac

[ "$target" != "$current" ] || exit 0

"$HOME/.config/hypr/scripts/brightness-set.sh" "$target" || exit 1
cleanup_run
[ -z "$qs_bin" ] || "$qs_bin" ipc --newest call brightness osd -- "$target" >/dev/null 2>&1 || true
