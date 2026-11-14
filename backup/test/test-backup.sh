#!/bin/sh
# Offline tests for backup/*.sh using stub restic and security binaries.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/backup-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

pass=0 fail=0
check() { if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); echo "FAIL $1"; fi; }

mkdir -p "$tmp/bin" "$tmp/home/docs" "$tmp/drive" "$tmp/nobin"
echo one >"$tmp/home/docs/a.txt"
echo two >"$tmp/home/docs/b.txt"
cat >"$tmp/conf" <<C
RESTIC_LOCAL_REPO="$tmp/drive/repo"
RESTIC_B2_REPO="b2:bucket:laptop"
KEYCHAIN_RESTIC_PASSWORD="pw"
KEYCHAIN_B2_KEY_ID="b2id"
KEYCHAIN_B2_APP_KEY="b2key"
INCLUDE_FILE="$tmp/include.txt"
EXCLUDE_FILE="$tmp/exclude.txt"
KEEP_DAILY=7 KEEP_WEEKLY=5 KEEP_MONTHLY=12 KEEP_YEARLY=3
CHECK_READ_SUBSET="5%"
RESTORE_SAMPLE=5
C
printf '# c\n~/docs\n~/missing\n' >"$tmp/include.txt"
printf '~/docs/skip\n*.tmp\n' >"$tmp/exclude.txt"

cat >"$tmp/bin/security" <<'S'
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = -s ] && s=$2; shift; done
case $s in pw|b2id|b2key) echo "secret-$s" ;; *) exit 44 ;; esac
S
cat >"$tmp/bin/restic" <<'S'
#!/bin/sh
echo "restic $* | repo=$RESTIC_REPOSITORY pwcmd=$RESTIC_PASSWORD_COMMAND b2=${B2_ACCOUNT_ID:-}" >>"$STUB_LOG"
case $1 in
backup) shift 2; cp "$1" "$STUB_LOG.files"; cp "$3" "$STUB_LOG.excl" ;;
ls) for f in "$HOME"/docs/*; do
	printf -- '-rw-r--r--   501    20 %6d %s %s\n' "$(wc -c <"$f")" "$(date -r "$f" '+%Y-%m-%d %H:%M:%S')" "$f"
    done ;;
restore) t=$4; shift 4
	while [ $# -gt 0 ]; do mkdir -p "$t$(dirname "$2")"; cp "$2" "$t$2"; [ -n "${STUB_CORRUPT:-}" ] && echo x >>"$t$2"; shift 2; done ;;
esac
S
chmod +x "$tmp/bin/"*
export HOME="$tmp/home" BACKUP_CONF="$tmp/conf" STUB_LOG="$tmp/log" USER=tester
P=$tmp/bin:/usr/bin:/bin

out=$(PATH=$tmp/nobin:/usr/bin:/bin "$here/backup.sh" local 2>&1)
check "missing restic fails clearly" '[ $? -ne 0 ] && echo "$out" | grep -q "restic not found"'

out=$(PATH=$P "$here/backup.sh" local 2>&1); rc=$?
check "backup local succeeds" '[ $rc -eq 0 ]'
check "files-from expands ~ and drops missing" '[ "$(cat "$tmp/log.files")" = "$tmp/home/docs" ]'
check "exclude file expands ~" 'grep -qx "$tmp/home/docs/skip" "$tmp/log.excl"'
check "password via keychain command, not value" 'grep -q "pwcmd=security find-generic-password -a tester -s pw -w" "$tmp/log" && ! grep -q secret-pw "$tmp/log"'
check "forget policy applied" 'grep -q "restic forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 3" "$tmp/log"'

: >"$tmp/log"
out=$(PATH=$P "$here/backup.sh" b2 2>&1)
check "b2 creds from keychain" 'grep -q "repo=b2:bucket:laptop.*b2=secret-b2id" "$tmp/log"'

rmdir "$tmp/drive"
out=$(PATH=$P "$here/backup.sh" all 2>&1); rc=$?
check "unmounted drive fails but b2 still runs" '[ $rc -ne 0 ] && echo "$out" | grep -q "not mounted" && grep -q "repo=b2:" "$tmp/log"'
mkdir "$tmp/drive"

sed 's/KEYCHAIN_RESTIC_PASSWORD="pw"/KEYCHAIN_RESTIC_PASSWORD="nope"/' "$tmp/conf" >"$tmp/conf2"
out=$(PATH=$P BACKUP_CONF="$tmp/conf2" "$here/check.sh" local 2>&1); rc=$?
check "missing keychain item fails clearly" '[ $rc -ne 0 ] && echo "$out" | grep -q "keychain item .nope. missing"'

out=$(PATH=$P "$here/restore-test.sh" local 2>&1); rc=$?
check "restore-test passes on identical restore" '[ $rc -eq 0 ] && echo "$out" | grep -q "2 sampled, 0 differ"'
out=$(PATH=$P STUB_CORRUPT=1 "$here/restore-test.sh" local 2>&1); rc=$?
check "restore-test detects corrupted restore" '[ $rc -ne 0 ] && echo "$out" | grep -q "2 differ"'
out=$(PATH=$P "$here/check.sh" local 2>&1)
check "check uses read-data-subset" 'grep -q "restic check --read-data-subset=5%" "$tmp/log"'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
