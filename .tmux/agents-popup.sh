#!/usr/bin/env bash
# Selectable agent list. Live-reloads while open; enter jumps to the pane.
export FZF_DEFAULT_OPTS=

fmt() {
  ~/.tmux/agents-list.sh \
  | sort -t$'\t' -k2,2 -k5,5rn \
  | awk -F'\t' '
      function icon(s) {
        if (s == "working") return "\033[33m◐\033[0m"
        if (s == "idle")    return "\033[32m○\033[0m"
        return "\033[90m·\033[0m"
      }
      {
        printf "%s\t%s \033[1m%-24.24s\033[0m \033[90m%-8s\033[0m %-52.52s \033[90m%5s\033[0m\n", \
          $1, icon($4), $2, $3, $7, $6
      }
    '
}

if [ "$1" = --list ]; then fmt; exit 0; fi

sel=$(fmt | fzf \
  --ansi \
  --with-nth 2.. \
  --delimiter=$'\t' \
  --layout=reverse \
  --info=inline \
  --prompt='agent> ' \
  --header='enter jump · ctrl-r reload · ctrl-k kill agent' \
  --preview 'tmux capture-pane -ep -t {1} -S -80' \
  --preview-window 'right,55%,wrap' \
  --bind "ctrl-r:reload($0 --list)" \
  --bind "ctrl-k:execute-silent(tmux send-keys -t {1} C-c)+reload($0 --list)" \
  --bind 'ctrl-/:change-preview-window(down,60%|hidden|right,55%)' \
  | cut -f1)

[ -n "$sel" ] || exit 0
tmux switch-client -t "$sel" \; select-pane -t "$sel"
