#My . files :)

basically this is just a place to put some stuff i wanna transfer across distros when i inevitably hop

## Laptop security, backup and git hooks

macOS first; scripts are POSIX `sh` and mostly work on Linux.

### Install

Not bundled; install them yourself:

- `gitleaks` (preferred) or `trufflehog`: secret scan in `security/inventory.sh`
- `restic`: everything in `backup/`
- `shellcheck` (optional): lint

### security/

- `security/inventory.sh [--no-git] [--no-backup] [--no-secrets] [root...]`: read-only report of
  - git repos under the roots with uncommitted changes, unpushed commits, stashes, no remote, or branches without upstream
  - entries under `$HOME` not covered by `backup/include.txt` (minus `backup/exclude.txt`; dotfiles only with `INVENTORY_HIDDEN=1`)
  - plaintext secrets via gitleaks (`--redact`) or trufflehog; only `file:line rule` is printed, never the value

  Roots default to existing `~/Documents ~/Desktop ~/Downloads ~/Developer ~/code ~/src ~/projects`; override with args or `INVENTORY_ROOTS=a:b`. Also `INVENTORY_DEPTH` (default 6), `INVENTORY_HOME`, `BACKUP_CONF`. Exit 1 when anything is flagged.
- `security/check.sh`: FileVault, SSH key passphrases or `sk-` hardware keys, password manager, plus manual items (Find My, offline 2FA recovery codes). See `security/CHECKLIST.md`.

### backup/ (3-2-1 with restic)

Copies: the laptop, a restic repo on an external drive, an encrypted restic repo on Backblaze B2.

- `backup/backup.conf`: repo locations, Keychain item names, retention, check subset. Use `BACKUP_CONF=/path/private.conf` to keep real bucket names out of this public repo.
- `backup/include.txt`, `backup/exclude.txt`: paths (`~` expands) and restic exclude patterns.
- `backup/init.sh [local|b2|all]`: `restic init`.
- `backup/backup.sh [local|b2|all]`: backup, then `forget.sh` (keep 7 daily, 5 weekly, 12 monthly, 3 yearly, then prune). An unmounted drive fails that target and continues with the others.
- `backup/forget.sh`, `backup/check.sh` (`restic check --read-data-subset=5%`).
- `backup/restore-test.sh [local|b2] [count]`: restores a random sample of files that are unchanged since the latest snapshot into a temp dir and compares them byte for byte.
- `backup/launchd/local.dotfiles.restore-reminder.plist`: notification on Feb 1 and Sep 15 to run the restore test. Not loaded by anything here.

Secrets come from the macOS Keychain (Linux: `secret-tool`), never files. restic reads the password itself via `RESTIC_PASSWORD_COMMAND`. One-time setup:

```sh
security add-generic-password -a "$USER" -s restic-laptop -w        # repo password (prompts)
security add-generic-password -a "$USER" -s restic-b2-key-id -w     # B2 application key ID
security add-generic-password -a "$USER" -s restic-b2-app-key -w    # B2 application key
backup/init.sh all
```

Use a B2 application key restricted to the one bucket. Keep the restic password in the password manager too: without it the backups are unreadable.

Load the semester reminder:

```sh
cp backup/launchd/local.dotfiles.restore-reminder.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.dotfiles.restore-reminder.plist
```

### git-hooks/ (global hooks via core.hooksPath)

Enable (not done by any script):

```sh
git config --global core.hooksPath "$PWD/git-hooks"
git config --global backup.gitlabGroup <gitlab-group-path>
```

- `pre-push`: when the remote's configured URL matches `github.com[:/]fr4nsyz/*`, pushes the same refs to `git@gitlab.com:<group>/<repo>.git`. GitLab push-to-create makes the project on first push, private by default.
  - Never forces: refspecs have no `+`, no `--force`. A force push to GitHub is therefore blocked because the GitLab push is rejected as non-fast-forward. Ref deletions are not mirrored.
  - A failed backup push fails the GitHub push. `BACKUP_SKIP=1 git push ...` skips the mirror.
  - Group: `BACKUP_GITLAB_GROUP` env, else `git config backup.gitlabGroup`; missing group blocks the push. Base URL: `BACKUP_GITLAB_URL` or `backup.gitlabUrl` (default `git@gitlab.com:`).
  - Git runs the hookdir hook even after a config hook (`hook.<name>.event pre-push`, e.g. a secret scan) failed, so before mirroring `pre-push` re-runs them via `git hook run`; any failure blocks the mirror and the push. Config pre-push hooks therefore run twice per mirrored push. Skipped on git without `git hook list`.
  - The mirror push runs with `--no-verify` and `BACKUP_HOOK_ACTIVE=1`, so it does not re-enter hooks.
- `core.hooksPath` disables `.git/hooks`, so `pre-push` runs the repo's own `.git/hooks/pre-push` first (same args and stdin), and the other hook names are symlinks to `chain-local`, which forwards to `.git/hooks/<name>`.
- A repo that sets its own local `core.hooksPath` (husky etc.) overrides the global one and skips these hooks.

### Tests

```sh
./run-tests.sh
```

Offline: temp repos with local bare "github" and "gitlab" remotes via `url.<path>.insteadOf`, a temp `GIT_CONFIG_GLOBAL`, and stub `restic`/`security`/`gitleaks` binaries.
