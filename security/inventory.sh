#!/bin/sh
# Read-only laptop inventory: risky git repos, files outside backup paths, plaintext secrets.
# Usage: inventory.sh [--no-git] [--no-backup] [--no-secrets] [root...]
# Env: INVENTORY_ROOTS (colon-separated), INVENTORY_DEPTH, INVENTORY_HOME, INVENTORY_HIDDEN=1, BACKUP_CONF.
# Exit: 0 clean, 1 findings, 2 usage or tool error.
here=$(cd "$(dirname "$0")" && pwd)
do_git=1 do_backup=1 do_secrets=1
while [ $# -gt 0 ]; do
	case $1 in
	--no-git) do_git= ;;
	--no-backup) do_backup= ;;
	--no-secrets) do_secrets= ;;
	-h|--help) sed -n '2,5p' "$0" | sed 's/^# //'; exit 0 ;;
	--) shift; break ;;
	-*) echo "inventory: unknown option $1" >&2; exit 2 ;;
	*) break ;;
	esac
	shift
done

if [ $# -eq 0 ]; then
	if [ -n "$INVENTORY_ROOTS" ]; then
		old=$IFS; IFS=:; set -- $INVENTORY_ROOTS; IFS=$old
	else
		for d in Documents Desktop Downloads Developer code src projects; do
			[ -d "$HOME/$d" ] && set -- "$@" "$HOME/$d"
		done
	fi
fi
depth=${INVENTORY_DEPTH:-6}
findings=0
flag() { findings=$((findings + 1)); }

git_section() {
	echo "## git repos"
	for root; do
		find "$root" -maxdepth "$depth" \( -name node_modules -o -name .Trash -o -name Library \) -prune -o \
			-name .git -print 2>/dev/null
	done | sort -u | while IFS= read -r gitdir; do
		repo=$(dirname "$gitdir")
		g() { git -C "$repo" "$@" 2>/dev/null; }
		issues=
		n=$(g status --porcelain | wc -l | tr -d ' ')
		[ "$n" -gt 0 ] && issues="$issues uncommitted=$n"
		n=$(g stash list | wc -l | tr -d ' ')
		[ "$n" -gt 0 ] && issues="$issues stashes=$n"
		[ -z "$(g remote)" ] && issues="$issues no-remote"
		g for-each-ref refs/heads --format='%(refname:short)|%(upstream)|%(upstream:track)' >"$tmp/br"
		while IFS='|' read -r br up track; do
			if [ -z "$up" ]; then
				issues="$issues no-upstream:$br"
			else
				case $track in
				*gone*) issues="$issues upstream-gone:$br" ;;
				*ahead*) issues="$issues unpushed:$br$(echo "$track" | sed 's/.*ahead \([0-9]*\).*/(+\1)/')" ;;
				esac
			fi
		done <"$tmp/br"
		[ -n "$issues" ] && echo "$repo:$issues"
	done >"$tmp/git"
	cat "$tmp/git"
	n=$(wc -l <"$tmp/git" | tr -d ' ')
	echo "repos with unsaved work: $n"
	[ "$n" -gt 0 ] && flag
}

load_backup_paths() {
	conf=${BACKUP_CONF:-$here/../backup/backup.conf}
	[ -r "$conf" ] || { echo "inventory: backup config not found: $conf" >&2; return 1; }
	INCLUDE_FILE=include.txt EXCLUDE_FILE=exclude.txt
	. "$conf"
	confdir=$(cd "$(dirname "$conf")" && pwd)
	case $INCLUDE_FILE in /*) ;; *) INCLUDE_FILE=$confdir/$INCLUDE_FILE ;; esac
	case $EXCLUDE_FILE in /*) ;; *) EXCLUDE_FILE=$confdir/$EXCLUDE_FILE ;; esac
	strip() { sed -e 's/^[[:space:]]*//' -e '/^#/d' -e '/^$/d' -e "s#^~#$HOME#" -e 's#/*$##' "$1"; }
	strip "$INCLUDE_FILE" >"$tmp/inc"
	strip "$EXCLUDE_FILE" >"$tmp/exc"
}

covered() {
	while IFS= read -r p; do
		case $1 in "$p"|"$p"/*) return 0 ;; esac
	done <"$tmp/inc"
	return 1
}

excluded() {
	b=$(basename "$1")
	while IFS= read -r p; do
		case $p in
		/*) case $1 in "$p"|"$p"/*) return 0 ;; esac ;;
		*) case $b in $p) return 0 ;; esac ;;
		esac
	done <"$tmp/exc"
	return 1
}

ancestor() {
	while IFS= read -r p; do
		case $p in "$1"/*) return 0 ;; esac
	done <"$tmp/inc"
	return 1
}

walk() {
	for c in "$1"/* "$1"/.[!.]*; do
		[ -e "$c" ] || [ -L "$c" ] || continue
		case $(basename "$c") in .*) [ -n "$INVENTORY_HIDDEN" ] || continue ;; esac
		covered "$c" && continue
		excluded "$c" && continue
		if [ -d "$c" ] && [ ! -L "$c" ] && ancestor "$c"; then
			walk "$c"
		else
			echo "$c"
		fi
	done
}

backup_section() {
	echo "## outside backup paths"
	load_backup_paths || { flag; return; }
	walk "${INVENTORY_HOME:-$HOME}" | tee "$tmp/out"
	n=$(wc -l <"$tmp/out" | tr -d ' ')
	echo "entries not backed up: $n"
	[ "$n" -gt 0 ] && flag
}

# Prints "file:line rule" per finding; secret values are never printed (gitleaks --redact).
secrets_section() {
	echo "## plaintext secrets"
	if command -v gitleaks >/dev/null 2>&1; then
		for root; do
			gitleaks dir "$root" --redact --no-banner --log-level error \
				--report-format json --report-path "$tmp/gl.json" >/dev/null 2>&1
			[ $? -le 1 ] || { echo "inventory: gitleaks failed on $root" >&2; flag; continue; }
			awk -F'"' '/^ *"RuleID":/ { r = $4 } /^ *"File":/ { f = $4 } /^ *"StartLine":/ { l = $3; gsub(/[^0-9]/, "", l) }
				/^ *}/ && r != "" { print f ":" l " " r; r = "" }' "$tmp/gl.json"
		done
	elif command -v trufflehog >/dev/null 2>&1; then
		for root; do
			trufflehog filesystem "$root" --json --no-update 2>/dev/null |
				sed -n 's/.*"file":"\([^"]*\)".*"line":\([0-9]*\).*"DetectorName":"\([^"]*\)".*/\1:\2 \3/p'
		done
	else
		echo "inventory: neither gitleaks nor trufflehog found; secret scan skipped (install gitleaks, see README)" >&2
		flag
		return
	fi >"$tmp/sec"
	cat "$tmp/sec"
	n=$(wc -l <"$tmp/sec" | tr -d ' ')
	echo "secret findings: $n"
	[ "$n" -gt 0 ] && flag
}

tmp=$(mktemp -d "${TMPDIR:-/tmp}/inventory.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
echo "roots: $*"
[ -n "$do_git" ] && git_section "$@"
[ -n "$do_backup" ] && backup_section
[ -n "$do_secrets" ] && secrets_section "$@"
[ "$findings" -eq 0 ]
