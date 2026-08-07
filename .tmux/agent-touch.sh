#!/usr/bin/env bash
# Stamp a pane with the current time. Fired from the pane-focus-out hook so
# "staleness" means "since I last looked at it", not "since it last printed".
[ -n "$1" ] || exit 0
exec tmux set -p -t "$1" @last_touch "$(date +%s)"
