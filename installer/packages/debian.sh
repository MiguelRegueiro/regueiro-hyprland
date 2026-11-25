#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
run_as_root apt install git stow "$@"
