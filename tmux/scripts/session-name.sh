#!/usr/bin/env bash
# Renames auto-generated tmux sessions (0, 1, 2 ...) to session-0, session-1 ...
# Sessions created with an explicit name are left untouched.
# Invoked from the session-created hook with the session name as $1.
set -eu

name=${1:-}
if [ -z "$name" ]; then
	name=$(tmux display-message -p '#{session_name}')
fi

# Only touch the numeric names tmux generates on its own.
case "$name" in
	'' | *[!0-9]*) exit 0 ;;
esac

target="session-$name"

# Never collide with an existing session.
if tmux has-session -t "=$target" 2>/dev/null; then
	i=$((name + 1))
	while tmux has-session -t "=session-$i" 2>/dev/null; do
		i=$((i + 1))
	done
	target="session-$i"
fi

tmux rename-session -t "=$name" "$target"
