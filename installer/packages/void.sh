#!/bin/sh
set -eu
. "$(dirname "$0")/root.sh"
install_catalog void "$(dirname -- "$0")/profiles/void.tsv" bootstrap "$@"
