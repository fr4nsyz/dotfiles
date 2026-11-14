#!/bin/sh
# Runs every offline shell test under */test/.
cd "$(dirname "$0")" || exit 1
to=
command -v timeout >/dev/null 2>&1 && to="timeout ${TEST_TIMEOUT:-300}"
rc=0
for t in */test/test-*.sh; do
	echo "### $t"
	$to sh "$t" || rc=1
done
exit $rc
