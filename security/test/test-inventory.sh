#!/bin/sh
# Offline tests for security/inventory.sh on a temp tree with a stub gitleaks.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/inventory-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig" HOME="$tmp/home"
git config --global user.name t; git config --global user.email t@example.invalid
git config --global init.defaultBranch main

pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

r=$tmp/home/Documents
mkdir -p "$r" "$tmp/bin" "$tmp/nobin" "$tmp/home/Movies" "$tmp/home/Library" "$tmp/home/Documents/node_modules"
git init -q --bare "$tmp/remote.git"
mk() { git init -q "$r/$1" && echo x >"$r/$1/f" && git -C "$r/$1" add f && git -C "$r/$1" commit -qm x; }
mk clean; git -C "$r/clean" remote add origin "$tmp/remote.git"; git -C "$r/clean" push -qu origin main:clean 2>/dev/null
git -C "$r/clean" branch -q --set-upstream-to=origin/clean
mk dirty; git -C "$r/dirty" remote add origin "$tmp/remote.git"; echo y >"$r/dirty/f"
mk ahead; git -C "$r/ahead" remote add origin "$tmp/remote.git"; git -C "$r/ahead" push -qu origin main:ahead 2>/dev/null
git -C "$r/ahead" branch -q --set-upstream-to=origin/ahead; echo z >"$r/ahead/f"; git -C "$r/ahead" commit -qam z
mk stashed; git -C "$r/stashed" remote add origin "$tmp/remote.git"; echo s >"$r/stashed/f"; git -C "$r/stashed" stash -q
mk deep/nested/norm
echo movie >"$tmp/home/Movies/m.mov"
mkdir -p "$tmp/home/Work/keep" "$tmp/home/Work/other"; echo k >"$tmp/home/Work/keep/k"; echo o >"$tmp/home/Work/other/o"
mkdir -p "$tmp/home/Unbacked"; echo a >"$tmp/home/Unbacked/a"; echo b >"$tmp/home/Unbacked/b"
echo hidden >"$tmp/home/.secretish"

mkdir -p "$tmp/cfg"
printf 'INCLUDE_FILE=inc\nEXCLUDE_FILE=exc\n' >"$tmp/cfg/b.conf"
printf '~/Documents\n~/Pictures/\n~/Work/keep\n' >"$tmp/cfg/inc"
printf '~/Library\n*.mov\n' >"$tmp/cfg/exc"
export BACKUP_CONF="$tmp/cfg/b.conf"

cat >"$tmp/bin/gitleaks" <<'S'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = --report-path ] && out=$2; shift; done
cat >"$out" <<J
[
 {
  "RuleID": "aws-access-token",
  "Description": "AWS",
  "StartLine": 3,
  "Match": "REDACTED",
  "Secret": "REDACTED",
  "File": "/x/creds.env",
  "Tags": []
 },
 {
  "RuleID": "generic-api-key",
  "StartLine": 9,
  "Secret": "REDACTED",
  "File": "/x/app.py",
  "Tags": []
 }
]
J
exit 1
S
chmod +x "$tmp/bin/gitleaks"

out=$(PATH=$tmp/nobin:/usr/bin:/bin "$here/inventory.sh" "$r" 2>&1); rc=$?
check "exit 1 on findings" '[ $rc -eq 1 ]'
check "clean repo not listed" '! echo "$out" | grep -q "/clean:"'
check "uncommitted reported" 'echo "$out" | grep -q "/dirty: uncommitted=1"'
check "unpushed reported" 'echo "$out" | grep -q "/ahead: unpushed:main(+1)"'
check "stash reported" 'echo "$out" | grep -q "/stashed:.*stashes=1"'
check "no upstream reported" 'echo "$out" | grep -q "/dirty:.*no-upstream:main"'
check "nested repo without remote reported" 'echo "$out" | grep -q "deep/nested/norm: no-remote no-upstream:main"'
check "node_modules pruned" '! echo "$out" | grep -q node_modules'
check "repo count" 'echo "$out" | grep -q "repos with unsaved work: 4"'
check "unbacked dir listed without file count" 'echo "$out" | grep -qx "$tmp/home/Unbacked"'
check "excluded paths skipped" '! echo "$out" | grep -Eq "/Library"'
check "covered paths skipped" '! echo "$out" | grep -qx "$tmp/home/Documents"'
check "ancestor of include walked" 'echo "$out" | grep -qx "$tmp/home/Work/other" && ! echo "$out" | grep -q "/Work/keep" && ! echo "$out" | grep -qx "$tmp/home/Work"'
check "hidden skipped by default" '! echo "$out" | grep -q .secretish'
check "missing scanner explained" 'echo "$out" | grep -q "neither gitleaks nor trufflehog found"'

out=$(PATH=$tmp/bin:/usr/bin:/bin INVENTORY_HIDDEN=1 "$here/inventory.sh" --no-git --no-backup "$r" 2>&1)
check "gitleaks findings as file:line rule" 'echo "$out" | grep -qx "/x/creds.env:3 aws-access-token" && echo "$out" | grep -qx "/x/app.py:9 generic-api-key"'
check "secret count" 'echo "$out" | grep -q "secret findings: 2"'
out=$(PATH=$tmp/bin:/usr/bin:/bin INVENTORY_HIDDEN=1 "$here/inventory.sh" --no-git --no-secrets 2>&1)
check "hidden listed with INVENTORY_HIDDEN=1" 'echo "$out" | grep -q .secretish'

mkdir -p "$tmp/thbin"
cat >"$tmp/thbin/trufflehog" <<'S'
#!/bin/sh
echo "$*" >"$TH_LOG"
echo '{"SourceMetadata":{"Data":{"Filesystem":{"file":"/x/k.pem","line":2}}},"DetectorName":"PrivateKey","Verified":false}'
S
chmod +x "$tmp/thbin/trufflehog"
out=$(PATH=$tmp/thbin:/usr/bin:/bin TH_LOG="$tmp/th.log" "$here/inventory.sh" --no-git --no-backup "$r" 2>&1)
check "trufflehog findings as file:line detector" 'echo "$out" | grep -qx "/x/k.pem:2 PrivateKey"'
check "trufflehog never verifies secrets live" 'grep -q -- "--no-verification" "$tmp/th.log"'

git -C "$r/dirty" status --porcelain >"$tmp/before"
check "read-only: worktree untouched" '[ "$(cat "$tmp/before")" = " M f" ] && [ "$(git -C "$r/stashed" stash list | wc -l | tr -d " ")" = 1 ]'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
