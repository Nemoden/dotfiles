#!/usr/bin/env bash
# Adjust @claude_subagents counter on current pane by $1 (+1 or -1).
# Clamps to >= 0. Recomputes window suffix after.
set -u

DELTA="${1:-0}"
[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

PANE="$TMUX_PANE"
CUR=$(tmux show-option -pqv -t "$PANE" '@claude_subagents' 2>/dev/null)
CUR="${CUR:-0}"
[[ "$CUR" =~ ^[0-9]+$ ]] || CUR=0

NEW=$((CUR + DELTA))
[ "$NEW" -lt 0 ] && NEW=0

tmux set-option -p -t "$PANE" '@claude_subagents' "$NEW" 2>/dev/null || true
"$(dirname "$0")/tmux-claude-recompute.sh" "$PANE"
exit 0
