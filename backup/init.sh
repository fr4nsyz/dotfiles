#!/bin/sh
# Create the restic repositories: init.sh [local|b2|all]
. "$(dirname "$0")/lib.sh"
load_conf
need_restic
run() { restic init; }
for_targets run "$@"
