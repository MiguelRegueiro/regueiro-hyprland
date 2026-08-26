#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

exec cc -O2 -pipe -std=c11 -Wall -Wextra -Werror \
    -o "$script_dir/qs-freebsd-hardware" \
    "$script_dir/qs-freebsd-hardware.c"
