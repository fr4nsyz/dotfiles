# Laptop security checklist

Run `security/check.sh` for the automated items; tick the manual ones by hand once a semester.

| Item | How it is verified |
| --- | --- |
| Full-disk encryption | `check.sh`: `fdesetup status` reports "FileVault is On" (Linux: a LUKS `crypt` device) |
| SSH keys protected | `check.sh`: every private key in `~/.ssh` either fails `ssh-keygen -y -P ''` (has a passphrase) or has an `sk-` public key (hardware key) |
| Password manager for secrets | `check.sh`: 1Password, Bitwarden, KeePassXC, Proton Pass, Apple Passwords or their CLIs present. Secrets live there, not in dotfiles or repos |
| No plaintext secrets on disk | `security/inventory.sh` (gitleaks or trufflehog). Move anything it finds into the password manager or Keychain |
| Unsaved work | `security/inventory.sh`: uncommitted changes, unpushed commits, stashes, branches without upstream |
| Files outside backups | `security/inventory.sh`: entries under `$HOME` not covered by `backup/include.txt` |
| Remote locate and wipe | Manual. System Settings > Apple ID > iCloud > Find My Mac on. Confirm the laptop shows at https://www.icloud.com/find. `check.sh` passes if the Find My NVRAM token is readable, otherwise prints MANUAL |
| Offline 2FA recovery codes | Manual. Recovery codes for GitHub, GitLab, Google, Apple ID and the password manager printed or on encrypted offline media, stored away from the laptop |
| Password manager emergency kit | Manual. Printed and stored with the recovery codes |
| Backups restore | `backup/restore-test.sh local` and `backup/restore-test.sh b2` once a semester (reminder plist in `backup/launchd/`) |
