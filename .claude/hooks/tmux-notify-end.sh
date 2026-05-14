#!/usr/bin/env bash
# Claude Code SessionEnd hook: unset pane state, recompute window suffix.
set -u

[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

tmux set-option -p -u -t "$TMUX_PANE" '@claude_state' 2>/dev/null || true
tmux set-option -p -u -t "$TMUX_PANE" '@claude_subagents' 2>/dev/null || true
"$(dirname "$0")/tmux-claude-recompute.sh" "$TMUX_PANE"
exit 0
