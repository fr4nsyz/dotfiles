# Shared helpers for backup/*.sh. Sourced, not executed.
BACKUP_DIR=$(cd "$(dirname "$0")" && pwd)

die() { echo "backup: $*" >&2; exit 1; }

load_conf() {
	conf=${BACKUP_CONF:-$BACKUP_DIR/backup.conf}
	[ -r "$conf" ] || die "config not found: $conf"
	. "$conf"
	confdir=$(cd "$(dirname "$conf")" && pwd)
	case $INCLUDE_FILE in /*) ;; *) INCLUDE_FILE=$confdir/$INCLUDE_FILE ;; esac
	case $EXCLUDE_FILE in /*) ;; *) EXCLUDE_FILE=$confdir/$EXCLUDE_FILE ;; esac
}

need_restic() {
	command -v restic >/dev/null 2>&1 ||
		die "restic not found in PATH; install it (see README 'Install') and retry"
}

secret_cmd() {
	if command -v security >/dev/null 2>&1; then
		echo "security find-generic-password -a $USER -s $1 -w"
	elif command -v secret-tool >/dev/null 2>&1; then
		echo "secret-tool lookup service $1"
	else
		die "no keychain tool (security or secret-tool) to read secret '$1'"
	fi
}

read_secret() {
	v=$(eval "$(secret_cmd "$1")" 2>/dev/null) && [ -n "$v" ] ||
		die "keychain item '$1' missing; add it with: security add-generic-password -a \"\$USER\" -s $1 -w"
	printf '%s' "$v"
}

# Sets restic env for target 'local' or 'b2'. Password is read by restic itself, never exported.
use_target() {
	unset B2_ACCOUNT_ID B2_ACCOUNT_KEY
	case $1 in
	local)
		[ -d "$(dirname "$RESTIC_LOCAL_REPO")" ] ||
			{ echo "backup: external drive not mounted ($(dirname "$RESTIC_LOCAL_REPO"))" >&2; return 1; }
		RESTIC_REPOSITORY=$RESTIC_LOCAL_REPO
		;;
	b2)
		B2_ACCOUNT_ID=$(read_secret "$KEYCHAIN_B2_KEY_ID") || return 1
		B2_ACCOUNT_KEY=$(read_secret "$KEYCHAIN_B2_APP_KEY") || return 1
		export B2_ACCOUNT_ID B2_ACCOUNT_KEY
		RESTIC_REPOSITORY=$RESTIC_B2_REPO
		;;
	*) echo "backup: unknown target '$1' (use local, b2 or all)" >&2; return 1 ;;
	esac
	read_secret "$KEYCHAIN_RESTIC_PASSWORD" >/dev/null || return 1
	RESTIC_PASSWORD_COMMAND=$(secret_cmd "$KEYCHAIN_RESTIC_PASSWORD")
	export RESTIC_REPOSITORY RESTIC_PASSWORD_COMMAND
}

# Expands a leading ~ in a path list, dropping comments and blank lines.
expand_list() {
	sed -e 's/^[[:space:]]*//' -e '/^#/d' -e '/^$/d' -e "s#^~#$HOME#" "$1"
}

# Runs "$1 <target>" for each target in $2.. (default all), each in a subshell; returns 1 if any failed, else 3 if any returned 3 (partial).
for_targets() {
	fn=$1; shift
	[ $# -gt 0 ] || set -- all
	[ "$1" = all ] && set -- local b2
	rc=0
	for t in "$@"; do
		echo "== $t" >&2
		( use_target "$t" && "$fn" "$t" )
		case $? in
		0) ;;
		3) echo "backup: $t partial" >&2; [ $rc -eq 1 ] || rc=3 ;;
		*) echo "backup: $t failed" >&2; rc=1 ;;
		esac
	done
	return $rc
}
