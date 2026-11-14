#!/bin/sh
# Runs every offline shell test under */test/.
cd "$(dirname "$0")" || exit 1
rc=0
for t in */test/test-*.sh; do
	echo "### $t"
	sh "$t" || rc=1
done
exit $rc
