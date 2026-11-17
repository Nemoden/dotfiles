#!/usr/bin/env bash
# Type TEXT into a Claude Code pane and press Enter, only when the pane is idle.
# Usage: send.sh [--wait SECS] [--dry-run] PANE TEXT
#   PANE   tmux pane id (%85). Ids stay fixed for the pane's life.
#   --wait retry every 60s up to SECS before giving up (default 0 = one try).
# Exit: 0 sent, 3 not idle (reason on stderr), 2 pane gone,
#       5 typed but not submitted cleanly (prompt cleared, reason on stderr).
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
  # copy mode turns typed keys into copy-mode commands; capture-pane hides it
  if [[ $(tmux display -p -t "$PANE" '#{pane_in_mode}' 2>/dev/null) == 1 ]]; then
    WHY="pane in copy mode (scrolled back)"; return 1
  fi
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

# Prompt line as shown, placeholder (dim) text removed. Claude Code puts a
# no-break space (c2 a0) after the ❯; make it a plain space.
prompt_line() {
  tmux capture-pane -p -e -t "$PANE" \
    | perl -pe 's/\e\[2m.*?\e\[0m//g; s/\e\[[0-9;]*m//g; s/\xc2\xa0/ /g' \
    | grep -E '^❯' | tail -1
}
prompt_empty() { grep -qE '^❯[^[:alnum:]]{0,4}$' <<<"$(prompt_line)"; }
# C-u deletes one wrapped line only; a long text spans several.
clear_prompt() {
  local i
  for i in $(seq 30); do
    prompt_empty && return 0
    tmux send-keys -t "$PANE" End C-u; sleep 0.3
  done
  prompt_empty
}
# The screen can be caught mid-redraw (subagent output, a new turn), so look
# up to 5 times before deciding. Usage: settle CHECK [ARG]
settle() { local i; for i in 1 2 3 4 5; do "$@" && return 0; sleep 1; done; return 1; }
prompt_has() { grep -qF -- "$1" <<<"$(prompt_line)"; }

# A long burst of keys can land as one paste. A paste is plain text, so a
# slash command inside it never runs, and "/cmd" glued to a paste is no
# command either. So type "/cmd " alone, then the rest (a paste is fine
# there), then Enter on its own.
if [[ $TEXT == /* && $TEXT == *' '* ]]; then
  CMD=${TEXT%% *}
  tmux send-keys -t "$PANE" -l -- "$CMD "
  sleep 0.5
  tmux send-keys -t "$PANE" -l -- "${TEXT#* }"
else
  CMD=''
  tmux send-keys -t "$PANE" -l -- "$TEXT"
fi
sleep 1
if [[ -n $CMD ]] && ! settle prompt_has "❯ $CMD "; then
  seen=$(prompt_line)
  clear_prompt || seen="$seen (COULD NOT CLEAR, prompt: $(prompt_line))"
  echo "command word lost in prompt: $seen" >&2; exit 5
fi
tmux send-keys -t "$PANE" Enter
sleep 1
# Enter swallowed into a paste leaves the text sitting in the prompt.
if ! settle prompt_empty; then
  seen=$(prompt_line)
  clear_prompt || seen="$seen (COULD NOT CLEAR, prompt: $(prompt_line))"
  echo "text still in prompt after Enter: $seen" >&2; exit 5
fi
