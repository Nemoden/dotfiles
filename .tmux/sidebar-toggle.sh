#!/usr/bin/env bash
# Toggle the agent sidebar in the current window.
# Identified by the @agent_sidebar pane option so it survives layout changes.
width=$(tmux show -gv @agent_sidebar_width 2>/dev/null)
width=${width:-44}

existing=$(tmux list-panes -F '#{pane_id} #{@agent_sidebar}' \
           | awk '$2 == "1" { print $1; exit }')

if [ -n "$existing" ]; then
  tmux kill-pane -t "$existing"
  exit 0
fi

# -b puts it left of the current pane, -d keeps focus where it is
pane=$(tmux split-window -h -b -l "$width" -d -P -F '#{pane_id}' '~/.tmux/sidebar.sh')
tmux set -p -t "$pane" @agent_sidebar 1
tmux set -p -t "$pane" @last_touch ''
