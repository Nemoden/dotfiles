#!/usr/bin/env bash
# Recompute window suffix from @claude_state on all panes in window containing $1 (pane id).
# States: working (●), idle (✓), blocked (⛔), waiting (❓)
# Suffix groups in fixed order: ⛔ ❓ ● ✓ (severity descending)
#
# Concurrency: callers set their own pane's state BEFORE calling this script, so each
# invocation's tmux list-panes already includes that caller's new state. Multiple
# concurrent invocations may produce transient stale rename-window writes, but the
# final state converges because the last writer always reads after its own set.
# No locking added unless a real wrong-final-state bug surfaces.
set -u

PANE="${1:-${TMUX_PANE:-}}"
[ -n "$PANE" ] || exit 0
[ -n "${TMUX:-}" ] || exit 0

WIN_ID=$(tmux display-message -p -t "$PANE" '#{window_id}' 2>/dev/null) || exit 0
[ -n "$WIN_ID" ] || exit 0

B=0  # blocked
Q=0  # waiting (question)
W=0  # working
I=0  # idle
S=0  # subagents (sum across all panes)
while IFS=$'\t' read -r state sub; do
  case "$state" in
    blocked) B=$((B+1));;
    waiting) Q=$((Q+1));;
    working) W=$((W+1));;
    idle)    I=$((I+1));;
  esac
  if [[ "$sub" =~ ^[0-9]+$ ]] && [ "$sub" -gt 0 ]; then
    S=$((S + sub))
  fi
done < <(tmux list-panes -t "$WIN_ID" -F '#{@claude_state}	#{@claude_subagents}' 2>/dev/null)

CUR_WIN=$(tmux display-message -p -t "$WIN_ID" '#W' 2>/dev/null || echo "")
# Strip any number of trailing status groups (glyph-runs or ⚒N) separated by spaces.
BASE_WIN="$CUR_WIN"
while :; do
  PREV="$BASE_WIN"
  BASE_WIN=$(sed -E 's/ +(⚒[0-9]+|[●✓⛔❓]+)$//' <<<"$BASE_WIN")
  [ "$BASE_WIN" = "$PREV" ] && break
done

build_group() {
  local n="$1" glyph="$2" out=""
  for ((k=0; k<n; k++)); do out+="$glyph"; done
  printf '%s' "$out"
}

PARTS=()
[ "$B" -gt 0 ] && PARTS+=("$(build_group "$B" '⛔')")
[ "$Q" -gt 0 ] && PARTS+=("$(build_group "$Q" '❓')")
[ "$W" -gt 0 ] && PARTS+=("$(build_group "$W" '●')")
[ "$I" -gt 0 ] && PARTS+=("$(build_group "$I" '✓')")
[ "$S" -gt 0 ] && PARTS+=("⚒$S")

SUFFIX=""
if [ "${#PARTS[@]}" -gt 0 ]; then
  SUFFIX=" $(IFS=' '; echo "${PARTS[*]}")"
fi

NEW_WIN="${BASE_WIN}${SUFFIX}"
[ "$NEW_WIN" = "$CUR_WIN" ] || tmux rename-window -t "$WIN_ID" "$NEW_WIN" 2>/dev/null || true

exit 0
