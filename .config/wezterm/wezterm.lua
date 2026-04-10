local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Font
config.font = wezterm.font('Monoid')
config.font_size = 12.0
config.line_height = 1.3

-- Tomorrow Night color scheme
config.colors = {
  foreground = '#c4c8c5',
  background = '#1d1f21',
  cursor_bg = '#c4c8c5',
  cursor_fg = '#1d1f21',
  cursor_border = '#c4c8c5',
  selection_fg = '#1d1f21',
  selection_bg = '#363a41',
  ansi = {
    '#000000', -- black
    '#cc6666', -- red
    '#b5bd68', -- green
    '#f0c574', -- yellow
    '#80a1bd', -- blue
    '#b294ba', -- magenta
    '#8abdb6', -- cyan
    '#fffefe', -- white
  },
  brights = {
    '#000000', -- bright black
    '#cc6666', -- bright red
    '#b5bd68', -- bright green
    '#f0c574', -- bright yellow
    '#80a1bd', -- bright blue
    '#b294ba', -- bright magenta
    '#8abdb6', -- bright cyan
    '#fffefe', -- bright white
  },
}

-- Cursor
config.default_cursor_style = 'BlinkingBar'

-- Window
config.window_decorations = 'RESIZE'
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Tab bar (retro style, top)
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false

-- macOS: left option key = alt (matches kitty macos_option_as_alt left)
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = true

-- Copy on select
config.selection_word_boundary = ' \t\n{}[]()"\',;:@'

-- Bell
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_duration_ms = 0,
  fade_out_duration_ms = 0,
}

-- Keybindings
config.keys = {
  -- Fullscreen toggle (matches macOS system shortcut)
  {
    key = 'f',
    mods = 'CTRL|CMD',
    action = wezterm.action.ToggleFullScreen,
  },
}

return config
