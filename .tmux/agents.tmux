# Herdr-like agent sidebar + selector.
# Source from ~/.tmux.conf:  source-file ~/.tmux/agents.tmux

# Staleness needs a "last time I was here" stamp. tmux only tracks output,
# so stamp on focus-out.
set -g focus-events on
set-hook -g pane-focus-out 'run-shell -b "~/.tmux/agent-touch.sh #{pane_id}"'

# prefix+a  selectable list (popup)
bind a display-popup -E -w 88% -h 60% '~/.tmux/agents-popup.sh'

# prefix+S  toggle the fixed left sidebar in the current window
bind S run-shell '~/.tmux/sidebar-toggle.sh'

# Sidebar width
set -g @agent_sidebar_width 44
