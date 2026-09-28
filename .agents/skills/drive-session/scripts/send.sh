#!/usr/bin/env bash
# Type TEXT into a Claude Code pane and press Enter, only when the pane is idle.
# Usage: send.sh [--wait SECS] [--dry-run] PANE TEXT
#   PANE   tmux pane id (%85). Ids stay fixed for the pane's life.
#   --wait retry every 60s up to SECS before giving up (default 0 = one try).
# Exit: 0 sent, 3 not idle (reason on stderr), 2 pane gone.
set -u
# Caller may run inside a private tmux server; $TMUX would send bare `tmux` there.
unset TMUX

WAIT=0 DRY=0
while [[ $# -gt 2 ]]; do
  case $1 in
    --wait) WAIT=$2; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown flag $1" >&2; exit 64 ;;
  esac
done
PANE=$1 TEXT=$2

# Sets WHY when not idle.
is_idle() {
  local s
  # ESC[2m = dim = placeholder suggestion in prompt box, not a typed draft.
  s=$(tmux capture-pane -p -e -t "$PANE" 2>/dev/null \
    | perl -pe 's/\e\[2m.*?\e\[0m//g; s/\e\[[0-9;]*m//g') || { WHY="pane gone"; return 2; }
  if grep -qE 'esc to interrupt|…[[:space:]]*\([0-9]+[ms]' <<<"$s"; then WHY="working"; return 1; fi
  if grep -qiE 'esc to (close|cancel)|do you want to proceed' <<<"$s"; then WHY="overlay or permission prompt open"; return 1; fi
  if ! grep -qE '^❯[^[:alnum:]]{0,4}$' <<<"$s"; then WHY="typed draft in prompt"; return 1; fi
}

tmux display -p -t "$PANE" '#{pane_id}' >/dev/null 2>&1 || { echo "pane gone" >&2; exit 2; }
waited=0
until is_idle; do
  if (( waited >= WAIT )); then echo "not idle: $WHY" >&2; exit 3; fi
  sleep 60; waited=$((waited+60))
done
if (( DRY )); then echo "DRY RUN: would send: $TEXT"; exit 0; fi
tmux send-keys -t "$PANE" -l -- "$TEXT"
sleep 1
tmux send-keys -t "$PANE" Enter
