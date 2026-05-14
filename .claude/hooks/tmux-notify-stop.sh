#!/usr/bin/env bash
# Claude Code Stop hook.
# Inside tmux: mark pane idle, recompute window suffix, maybe notify.
# Outside tmux: just notify (no window concept).
set -u

# Read hook payload for cwd fallback (used outside tmux).
PAYLOAD=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null || echo "")
CWD="${CWD:-$PWD}"

is_terminal_frontmost() {
  local front
  front=$(osascript -e 'tell application "System Events" to name of first process whose frontmost is true' 2>/dev/null || echo "")
  case "$front" in
    kitty|iTerm2|Terminal|Alacritty|WezTerm|Ghostty) return 0;;
    "") return 0;;  # unknown — assume yes, don't spam
    *) return 1;;
  esac
}

notify() {
  local title="$1" msg="$2"
  osascript -e "display notification \"${msg//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
}

if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  PANE="$TMUX_PANE"
  tmux set-option -p -t "$PANE" '@claude_state' 'idle' 2>/dev/null || true
  "$(dirname "$0")/tmux-claude-recompute.sh" "$PANE"

  SESSION=$(tmux display-message -p -t "$PANE" '#S' 2>/dev/null || echo "")
  WIN_IDX=$(tmux display-message -p -t "$PANE" '#I' 2>/dev/null || echo "")
  WIN_NAME=$(tmux display-message -p -t "$PANE" '#W' 2>/dev/null || echo "")
  BASE_WIN="$WIN_NAME"
  while :; do
    PREV="$BASE_WIN"
    BASE_WIN=$(sed -E 's/ +(⚒[0-9]+|[●✓⛔❓]+)$//' <<<"$BASE_WIN")
    [ "$BASE_WIN" = "$PREV" ] && break
  done

  if is_terminal_frontmost; then
    # Suppress only if user is actively viewing THIS pane.
    # Compares pane that fired the hook against the active pane of any attached client.
    SUPPRESS=0
    while IFS= read -r active_pane; do
      [ "$active_pane" = "$PANE" ] && SUPPRESS=1
    done < <(tmux list-clients -F '#{pane_id}' 2>/dev/null)
    [ "$SUPPRESS" = "1" ] && exit 0
  fi
  notify "claude done" "${SESSION}:${WIN_IDX} ${BASE_WIN}"
  exit 0
fi

# Outside tmux: no window context. Only suppress if terminal frontmost.
is_terminal_frontmost && exit 0
notify "claude done" "$(basename "$CWD")"
exit 0
