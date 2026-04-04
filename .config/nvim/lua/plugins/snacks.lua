return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile      = { enabled = true },
    dashboard    = { enabled = true },
    explorer     = {
      enabled = true,
      replace_netrw = true,
    },
    git          = { enabled = true },
    indent       = { enabled = false },
    input        = { enabled = true },
    notifier     = { enabled = true, timeout = 3000 },
    picker       = { enabled = false },
    quickfile    = { enabled = false },
    scope        = { enabled = false },
    scroll       = { enabled = false },
    statuscolumn = { enabled = false },
    words        = { enabled = true },
  },
  keys = {
    -- Explorer (replaces nvim-tree)
    { "<leader>ee", function() Snacks.explorer.open() end,                            desc = "Toggle file explorer" },
    { "<leader>ef", function() Snacks.explorer.open({ focus = true }) end,            desc = "Focus file explorer on current file" },
    { "<leader>ec", function() Snacks.explorer.open({ layout = { position = "left" } }) end, desc = "Open file explorer" },
    -- Git
    { "<leader>gg", function() Snacks.git.blame_line() end,                           desc = "Git blame line" },
    { "<leader>gB", function() Snacks.gitbrowse() end,                                desc = "Open in browser" },
  },
}
