#!/usr/bin/env bash
# Persistent sidebar pane: redraws the agent tree every REFRESH seconds.
# Display-only. Use prefix+a for the selectable popup.
REFRESH=${HERDR_SIDEBAR_REFRESH:-2}

printf '\e[?25l'                              # hide cursor
trap 'printf "\e[?25h\e[?1049l"; exit 0' INT TERM EXIT
printf '\e[?1049h'                            # alt screen, keeps scrollback clean

while true; do
  out=$(COLUMNS=$(tput cols) ~/.tmux/sidebar-render.sh)
  printf '\e[H\e[2J%s' "$out"                 # home, clear, draw in one write
  sleep "$REFRESH"
done
