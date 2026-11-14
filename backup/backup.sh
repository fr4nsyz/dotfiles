#!/bin/sh
# Back up include.txt paths, then apply the forget/prune policy: backup.sh [local|b2|all]
. "$(dirname "$0")/lib.sh"
load_conf
need_restic
list=$(mktemp "${TMPDIR:-/tmp}/restic-files.XXXXXX") || exit 1
excl=$(mktemp "${TMPDIR:-/tmp}/restic-excl.XXXXXX") || exit 1
trap 'rm -f "$list" "$excl"' EXIT
expand_list "$INCLUDE_FILE" | while IFS= read -r p; do
	if [ -e "$p" ]; then echo "$p"; else echo "backup: skipping missing $p" >&2; fi
done >"$list"
expand_list "$EXCLUDE_FILE" >"$excl"
[ -s "$list" ] || die "nothing to back up (check $INCLUDE_FILE)"
# restic rc 3: snapshot saved but some files were unreadable (e.g. no Full Disk Access).
run() {
	restic backup --files-from-verbatim "$list" --exclude-file "$excl" --exclude-caches
	r=$?
	[ $r -eq 0 ] || [ $r -eq 3 ] || return $r
	"$BACKUP_DIR/forget.sh" "$1" || return 1
	return $r
}
for_targets run "$@"
