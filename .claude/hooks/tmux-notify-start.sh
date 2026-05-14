#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: mark pane as working, recompute window suffix.
set -u

[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

tmux set-option -p -t "$TMUX_PANE" '@claude_state' 'working' 2>/dev/null || true
"$(dirname "$0")/tmux-claude-recompute.sh" "$TMUX_PANE"
exit 0
