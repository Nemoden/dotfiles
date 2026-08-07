#!/usr/bin/env bash
# Single source of truth for agent inventory, sourced from pane titles.
#
# Emits TSV, one row per agent pane:
#   col1  pane_id           (%199)
#   col2  session           (authz)
#   col3  location          (authz:3.1)
#   col4  state             (working|idle|unknown)
#   col5  age_seconds       (-1 when never touched)
#   col6  age_human         (4m, 2h, —)
#   col7  topic             (from pane title)
#
# Pane title convention, set by the agents themselves:
#   "✳ <topic>"        idle
#   "<braille> <topic>" working
AGENT_COMMANDS='claude|codex|gemini|cursor|opencode|amp|droid|pi|crush|aider'

now=$(date +%s)

tmux list-panes -a -F '#{pane_id}|#{session_name}|#{session_name}:#{window_index}.#{pane_index}|#{pane_current_command}|#{@last_touch}|#{pane_title}' \
| while IFS='|' read -r id session loc cmd touch title; do
    [[ "$cmd" =~ ^($AGENT_COMMANDS)$ ]] || continue

    case "$title" in
      '✳ '*)     state=idle;    topic=${title#✳ } ;;
      [⠀-⣿]' '*) state=working; topic=${title#* } ;;
      *)         state=unknown; topic=$title ;;
    esac

    if [ -z "$touch" ]; then
      age=-1
      ago="—"
    else
      age=$(( now - touch ))
      if   [ "$age" -lt 300 ];   then ago="${age}s"
      elif [ "$age" -lt 3600 ];  then ago="$((age/60))m"
      elif [ "$age" -lt 86400 ]; then ago="$((age/3600))h"
      else                            ago="$((age/86400))d"
      fi
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$id" "$session" "$loc" "$state" "$age" "$ago" "$topic"
  done
