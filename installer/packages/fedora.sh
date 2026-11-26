#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
install_catalog fedora "$(dirname -- "$0")/profiles/fedora.tsv" base "$@"
