#!/bin/sh
# Offline tests for git-hooks/pre-push using local bare "github" and "gitlab" remotes.
set -u
hooks=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/pre-push-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$tmp/gitconfig"
unset BACKUP_SKIP BACKUP_GITLAB_GROUP BACKUP_GITLAB_URL BACKUP_HOOK_ACTIVE 2>/dev/null || true
git config --global user.name test
git config --global user.email test@example.invalid
git config --global init.defaultBranch main
git config --global core.hooksPath "$hooks"
git config --global backup.gitlabGroup backup-group
git config --global url."$tmp/github/".insteadOf https://github.com/
git config --global url."$tmp/gitlab/".insteadOf git@gitlab.com:

pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
no() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else no "$1"; fi; }
sha() { git -C "$1" rev-parse -q --verify "$2" 2>/dev/null; }

mkdir -p "$tmp/github/fr4nsyz" "$tmp/github/someoneelse" "$tmp/gitlab/backup-group"
for r in github/fr4nsyz/proj github/someoneelse/other gitlab/backup-group/proj gitlab/backup-group/other; do
	git init -q --bare "$tmp/$r.git"
done
gh="$tmp/github/fr4nsyz/proj.git"
gl="$tmp/gitlab/backup-group/proj.git"

git init -q "$tmp/work"
cd "$tmp/work" || exit 1
git remote add origin https://github.com/fr4nsyz/proj.git
git remote add other https://github.com/someoneelse/other.git
cat >.git/hooks/pre-push <<'H'
#!/bin/sh
{ echo "args:$*"; cat; } >>"$(git rev-parse --git-dir)/local-pre-push.log"
[ ! -e "$(git rev-parse --git-dir)/local-pre-push.fail" ]
H
cat >.git/hooks/pre-commit <<'H'
#!/bin/sh
echo ran >>"$(git rev-parse --git-dir)/local-pre-commit.log"
H
chmod +x .git/hooks/pre-push .git/hooks/pre-commit
echo a >f && git add f && git commit -qm a
check "local pre-commit chained via wrapper" '[ -s .git/local-pre-commit.log ]'

git push -q origin main 2>/dev/null
check "github push succeeds" '[ "$(sha "$gh" main)" = "$(git rev-parse main)" ]'
check "backup push mirrors branch to gitlab" '[ "$(sha "$gl" main)" = "$(git rev-parse main)" ]'
check "local pre-push gets args and stdin" 'grep -q "^args:origin " .git/local-pre-push.log && grep -q "refs/heads/main" .git/local-pre-push.log'
check "local pre-push runs once (no recursion on gitlab push)" '[ "$(grep -c "^args:" .git/local-pre-push.log)" -eq 1 ]'

git tag -a v1 -m v1 && git push -q origin v1 2>/dev/null
check "tag mirrored" '[ "$(sha "$gl" refs/tags/v1)" = "$(git rev-parse v1)" ]'

git push -q other main 2>/dev/null
check "non-fr4nsyz remote pushes" '[ -n "$(sha "$tmp/github/someoneelse/other.git" main)" ]'
check "non-fr4nsyz remote not mirrored" '[ -z "$(sha "$tmp/gitlab/backup-group/other.git" main)" ]'

touch .git/local-pre-push.fail
echo b >f && git commit -qam b
git push -q origin main 2>/dev/null
check "failing local pre-push blocks push" '[ "$(sha "$gh" main)" != "$(git rev-parse main)" ] && [ "$(sha "$gl" main)" != "$(git rev-parse main)" ]'
rm .git/local-pre-push.fail

mv "$gl" "$gl.off"
git push -q origin main 2>/dev/null
check "backup failure blocks github push" '[ "$(sha "$gh" main)" != "$(git rev-parse main)" ]'
BACKUP_SKIP=1 git push -q origin main 2>/dev/null
check "BACKUP_SKIP=1 overrides" '[ "$(sha "$gh" main)" = "$(git rev-parse main)" ]'
mv "$gl.off" "$gl"
echo b3 >f && git commit -qam b3
git push -q origin main 2>/dev/null
check "backup catches up on next push" '[ "$(sha "$gl" main)" = "$(git rev-parse main)" ]'

before=$(sha "$gl" main)
git commit -q --amend -m b2
git push -q --force origin main 2>/dev/null
check "force push to github is blocked" '[ "$(sha "$gh" main)" = "$before" ]'
check "gitlab never force-updated" '[ "$(sha "$gl" main)" = "$before" ]'
git reset -q --hard "$before"

git push -q origin main:refs/heads/feature 2>/dev/null
git push -q origin :refs/heads/feature 2>/dev/null
check "ref deletion reaches github" '[ -z "$(sha "$gh" refs/heads/feature)" ]'
check "ref deletion skipped on gitlab" '[ -n "$(sha "$gl" refs/heads/feature)" ]'

git config --global --unset backup.gitlabGroup
echo c >f && git commit -qam c
git push -q origin main 2>/dev/null
check "missing group blocks push" '[ "$(sha "$gh" main)" != "$(git rev-parse main)" ]'
BACKUP_GITLAB_GROUP=backup-group git push -q origin main 2>/dev/null
check "group from env" '[ "$(sha "$gl" main)" = "$(git rev-parse main)" ]'

git config --global backup.gitlabGroup backup-group
git config --global hook.scan.event pre-push
git config --global hook.scan.command false
echo d >f && git commit -qam d
git push -q origin main 2>/dev/null
check "failing config hook blocks gitlab mirror" '[ "$(sha "$gl" main)" != "$(git rev-parse main)" ] && [ "$(sha "$gh" main)" != "$(git rev-parse main)" ]'
git config --global hook.scan.command 'echo ran >>"$(git rev-parse --git-dir)/scan.log"'
git push -q origin main 2>/dev/null
check "passing config hook allows mirror" '[ "$(sha "$gl" main)" = "$(git rev-parse main)" ] && [ "$(sha "$gh" main)" = "$(git rev-parse main)" ]'
check "config hook runs twice per mirrored push" '[ "$(grep -c ran .git/scan.log)" -eq 2 ]'
git config --global --remove-section hook.scan

check "hook has no force flags or + refspecs" '! grep -Eq -- "--force|\"\\+" "$hooks/pre-push"'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
