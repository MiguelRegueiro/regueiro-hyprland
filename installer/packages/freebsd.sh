#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
run_as_root pkg install git stow "$@"
