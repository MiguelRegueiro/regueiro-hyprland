#!/bin/sh
# Stable public entry point. Installer implementation lives under installer/.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$repo_dir/installer/install.sh" "$@"
