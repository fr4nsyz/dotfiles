#!/bin/sh
# Tests the SSH passphrase detection in security/check.sh with throwaway keys.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/check-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

ssh-keygen -q -t ed25519 -N '' -C t -f "$tmp/nopass"
ssh-keygen -q -t ed25519 -N 'correct horse' -C t -f "$tmp/withpass"
ssh-keygen -q -t ed25519 -N '' -C t -f "$tmp/hw"
printf 'sk-ssh-ed25519@openssh.com AAAA t\n' >"$tmp/hw.pub"
out=$(SSH_DIR=$tmp "$here/check.sh" 2>&1); rc=$?
check "unprotected key fails" 'echo "$out" | grep -q "FAIL   ssh key nopass has no passphrase"'
check "passphrase key passes" 'echo "$out" | grep -q "PASS   ssh key withpass has a passphrase"'
check "sk- key passes as hardware" 'echo "$out" | grep -q "PASS   ssh key hw is a hardware"'
check "public keys ignored" '! echo "$out" | grep -q "\.pub"'
check "exit nonzero on failure" '[ $rc -ne 0 ]'
check "manual items listed" 'echo "$out" | grep -q "MANUAL offline 2FA recovery codes"'
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
