local util = require("util")
return {
  'echasnovski/mini.files',
  version = false,
  opts = {
    mappings = {
      close       = 'q',
      go_in       = 'L',
      go_in_plus  = 'l',
      go_out      = 'H',
      go_out_plus = 'h',
      mark_goto   = "'",
      mark_set    = 'm',
      reset       = '<BS>',
      reveal_cwd  = '@',
      show_help   = 'g?',
      synchronize = '=',
      trim_left   = '<',
      trim_right  = '>',
    },
    windows = {
      max_number = 4,
      preview = false,
    }
  },
  keys = {
    {
      "<localleader>e", function() require('mini.files').open(util.get_file_path(), true) end, desc = 'Explorer',
    }
  }
}
