#!/bin/sh
# Restore a random sample of unchanged files from the latest snapshot into a temp dir and compare.
# Usage: restore-test.sh [local|b2] [count]
. "$(dirname "$0")/lib.sh"
load_conf
need_restic
target=${1:-local}
count=${2:-$RESTORE_SAMPLE}
use_target "$target" || exit 1

tmp=$(mktemp -d "${TMPDIR:-/tmp}/restore-test.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT

# restic ls -l: mode uid gid size date time path; keep regular files as "date time<TAB>path".
restic ls -l latest >"$tmp/ls" || die "restic ls failed"
awk 'BEGIN { srand() }
	/^-/ { m = $5 " " $6; sub(/^[^ ]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9-]+ +[0-9:]+ /, "")
	       print rand() "\t" m "\t" $0 }' "$tmp/ls" | sort -n | cut -f2- >"$tmp/candidates"

# Only files whose live mtime still matches the snapshot can be compared byte for byte.
: >"$tmp/sample"
n=0
while IFS="$(printf '\t')" read -r mtime path && [ "$n" -lt "$count" ]; do
	[ -f "$path" ] || continue
	[ "$(date -r "$path" '+%Y-%m-%d %H:%M:%S')" = "$mtime" ] || continue
	printf '%s\n' "$path" >>"$tmp/sample"
	n=$((n + 1))
done <"$tmp/candidates"
[ "$n" -gt 0 ] || die "no unchanged files found in latest snapshot to test"

set --
while IFS= read -r p; do set -- "$@" --include "$p"; done <"$tmp/sample"
restic restore latest --target "$tmp/out" "$@" >/dev/null || die "restic restore failed"

bad=0
while IFS= read -r p; do
	if cmp -s "$tmp/out$p" "$p"; then echo "ok   $p"; else echo "DIFF $p"; bad=$((bad + 1)); fi
done <"$tmp/sample"
echo "restore-test ($target): $n sampled, $bad differ"
[ "$bad" -eq 0 ]
