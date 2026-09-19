#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d /tmp/qs-auth-test.XXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
cp "$repo_root/scripts/tests/lock/auth.qml" "$test_dir/shell.qml"
cp "$repo_root/quickshell/.config/quickshell/lockscreen/AuthController.qml" "$test_dir/"
mkdir -m 700 "$test_dir/runtime"
QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_CONTROLS_STYLE=Basic XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15s qs -p "$test_dir/shell.qml"
cp "$repo_root/scripts/tests/lock/pam.qml" "$test_dir/pam-test.qml"
mkdir "$test_dir/pam"
printf 'auth required pam_permit.so\n' > "$test_dir/pam/permit"
printf 'auth required pam_deny.so\n' > "$test_dir/pam/deny"
for policy in permit deny; do
    LOCK_TEST_PAM_CONFIG="$policy" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_CONTROLS_STYLE=Basic XDG_RUNTIME_DIR="$test_dir/runtime" timeout 15s qs -p "$test_dir/pam-test.qml"
done
