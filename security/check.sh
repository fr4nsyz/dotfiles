#!/bin/sh
# Verify laptop security baseline (see CHECKLIST.md). Exit 1 if any automated check fails.
# Env: SSH_DIR (default ~/.ssh).
fails=0
pass() { echo "PASS   $*"; }
fail() { echo "FAIL   $*"; fails=$((fails + 1)); }
manual() { echo "MANUAL $*"; }

if command -v fdesetup >/dev/null 2>&1; then
	if fdesetup status 2>/dev/null | grep -q "FileVault is On"; then pass "FileVault on"; else fail "FileVault off (System Settings > Privacy & Security > FileVault)"; fi
elif command -v lsblk >/dev/null 2>&1 && lsblk -o TYPE 2>/dev/null | grep -q crypt; then
	pass "LUKS volume present"
else
	manual "full-disk encryption: could not verify on this OS"
fi

ssh_dir=${SSH_DIR:-$HOME/.ssh}
keys=0
for k in "$ssh_dir"/*; do
	[ -f "$k" ] || continue
	head -n 1 "$k" 2>/dev/null | grep -q -- '-----BEGIN .*PRIVATE KEY-----' || continue
	keys=$((keys + 1))
	if [ -f "$k.pub" ] && grep -q '^sk-' "$k.pub"; then
		pass "ssh key $(basename "$k") is a hardware (sk-) key"
	elif ssh-keygen -y -P '' -f "$k" >/dev/null 2>&1; then
		fail "ssh key $(basename "$k") has no passphrase (ssh-keygen -p -f $k)"
	else
		pass "ssh key $(basename "$k") has a passphrase"
	fi
done
[ "$keys" -gt 0 ] || pass "no ssh private keys in $ssh_dir"

pm=
for app in 1Password 1Password\ 7 Bitwarden KeePassXC "Proton Pass" Dashlane Enpass; do
	[ -d "/Applications/$app.app" ] && pm="$pm, $app"
done
for cli in op bw keepassxc-cli pass; do
	command -v "$cli" >/dev/null 2>&1 && pm="$pm, $cli"
done
[ -d /System/Applications/Passwords.app ] && pm="$pm, Apple Passwords"
if [ -n "$pm" ]; then pass "password manager present:${pm#,}"; else fail "no password manager found"; fi

if nvram fmm-mobileme-token-FMM >/dev/null 2>&1; then
	pass "Find My Mac token present (still confirm remote wipe at https://www.icloud.com/find)"
else
	manual "Find My Mac: System Settings > Apple ID > iCloud > Find My Mac on; test locate at https://www.icloud.com/find"
fi
manual "offline 2FA recovery codes: printed or on encrypted offline media for GitHub, GitLab, Google, Apple, password manager"
manual "password manager emergency kit stored offline"

echo "failed: $fails"
[ "$fails" -eq 0 ]
