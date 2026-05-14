#!/usr/bin/env bash
# Claude Code Notification hook: mark pane blocked or waiting based on notification_type.
# Settings.json wires this with a matcher so we only fire on relevant types,
# but we also re-check from stdin in case matcher behavior changes.
set -u

[ -n "${TMUX:-}" ] || exit 0
[ -n "${TMUX_PANE:-}" ] || exit 0

PAYLOAD=$(cat)
TYPE=$(printf '%s' "$PAYLOAD" | jq -r '.notification_type // empty' 2>/dev/null || echo "")

case "$TYPE" in
  permission_prompt|elicitation_dialog)
    STATE='blocked';;
  *)
    exit 0;;
esac

tmux set-option -p -t "$TMUX_PANE" '@claude_state' "$STATE" 2>/dev/null || true
"$(dirname "$0")/tmux-claude-recompute.sh" "$TMUX_PANE"
exit 0
