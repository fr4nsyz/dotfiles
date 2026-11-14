#!/bin/sh
# Verify repository structure and a random subset of pack data: check.sh [local|b2|all]
. "$(dirname "$0")/lib.sh"
load_conf
need_restic
run() { restic check --read-data-subset="$CHECK_READ_SUBSET"; }
for_targets run "$@"
