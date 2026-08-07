#!/usr/bin/env bash
# Renders the agent tree for the sidebar pane: sessions as headers, agents nested.
# Width-aware; reads terminal columns so it degrades gracefully in a narrow pane.
cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 40)}
current_session=$(tmux display -p '#{session_name}' 2>/dev/null)
active_pane=$(tmux display -p '#{pane_id}' 2>/dev/null)

DIM=$'\e[90m'
RESET=$'\e[0m'
BOLD=$'\e[1m'
HDR=$'\e[1;34m'
HDR_CUR=$'\e[1;33m'

~/.tmux/agents-list.sh \
| sort -t$'\t' -k2,2 -k5,5rn \
| awk -F'\t' \
    -v cols="$cols" \
    -v cur="$current_session" \
    -v active="$active_pane" \
    -v dim="$DIM" -v reset="$RESET" -v bold="$BOLD" \
    -v hdr="$HDR" -v hdrcur="$HDR_CUR" '
  function icon(state) {
    if (state == "working") return "\033[33m◐\033[0m"
    if (state == "idle")    return "\033[32m○\033[0m"
    return dim "·" reset
  }
  {
    id = $1; session = $2; loc = $3; state = $4; ago = $6; topic = $7

    if (session != last_session) {
      if (NR > 1) print ""
      c = (session == cur) ? hdrcur : hdr
      printf "%s%s%s\n", c, session, reset
      last_session = session
      idx = 0
    }
    idx++

    # window.pane suffix only; session name is already the header
    split(loc, p, ":")
    wp = p[2]

    marker = (id == active) ? bold "▸" reset : " "

    # topic budget: total - marker(2) - icon(2) - wp(5) - age(6) - gaps
    budget = cols - 18
    if (budget < 8) budget = 8
    t = topic
    if (length(t) > budget) t = substr(t, 1, budget - 1) "…"

    printf "%s %s %s%-4s%s %-*s %s%4s%s\n", \
      marker, icon(state), dim, wp, reset, budget, t, dim, ago, reset
  }
'
