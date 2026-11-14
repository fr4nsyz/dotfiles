#!/bin/sh
# Apply the retention policy from backup.conf and prune: forget.sh [local|b2|all]
. "$(dirname "$0")/lib.sh"
load_conf
need_restic
run() {
	restic forget --prune --keep-daily "$KEEP_DAILY" --keep-weekly "$KEEP_WEEKLY" \
		--keep-monthly "$KEEP_MONTHLY" --keep-yearly "$KEEP_YEARLY"
}
for_targets run "$@"
