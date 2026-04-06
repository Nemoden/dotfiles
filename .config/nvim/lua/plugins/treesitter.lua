local parsers = {
  "bash",
  "clojure",
  "commonlisp",
  "css",
  "csv",
  "diff",
  "dockerfile",
  "fish",
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "graphql",
  "helm",
  "html",
  "java",
  "javascript",
  "jinja",
  "jinja_inline",
  "jq",
  "json",
  "json5",
  "kotlin",
  "lua",
  "luadoc",
  "luau",
  "markdown",
  "markdown_inline",
  "mermaid",
  "nginx",
  "php",
  "php_only",
  "phpdoc",
  "proto",
  "python",
  "regex",
  "rust",
  "scala",
  "scheme",
  "scss",
  "sql",
  "ssh_config",
  "terraform",
  "tmux",
  "toml",
  "tsx",
  "twig",
  "typescript",
  "vim",
  "vimdoc",
  "vue",
  "xml",
  "yaml",
  "zig",
}

local function should_disable(lang, buf)
  if lang == "html" then
    return true
  end

  local max_filesize = 100 * 1024
  local fs_stat = (vim.uv or vim.loop).fs_stat
  local ok, stats = pcall(fs_stat, vim.api.nvim_buf_get_name(buf))
  if ok and stats and stats.size > max_filesize then
    vim.schedule(function()
      vim.notify(
        "File larger than 100KB treesitter disabled for performance",
        vim.log.levels.WARN,
        { title = "Treesitter" }
      )
    end)
    return true
  end

  return false
end

local function setup_textobjects()
  local ok, textobjects = pcall(require, "nvim-treesitter-textobjects")
  if not ok or type(textobjects.setup) ~= "function" then
    return
  end

  textobjects.setup({
    select = {
      lookahead = true,
      include_surrounding_whitespace = false,
    },
    move = {
      set_jumps = true,
    },
  })

  local select = require("nvim-treesitter-textobjects.select")
  local move = require("nvim-treesitter-textobjects.move")

  local select_keymaps = {
    af = "@function.outer",
    ["if"] = "@function.inner",
    ac = "@class.outer",
    ic = "@class.inner",
    al = "@loop.outer",
    il = "@loop.inner",
    ["a?"] = "@conditional.outer",
    ["i?"] = "@conditional.inner",
    aa = "@parameter.outer",
    ia = "@parameter.inner",
    ["as"] = "@statement.outer",
    ["is"] = "@statement.inner",
  }

  for lhs, capture in pairs(select_keymaps) do
    vim.keymap.set({ "x", "o" }, lhs, function()
      select.select_textobject(capture, "textobjects")
    end, { silent = true })
  end

  vim.keymap.set({ "n", "x", "o" }, "]f", function()
    move.goto_next_start("@function.outer", "textobjects")
  end, { silent = true })
  vim.keymap.set({ "n", "x", "o" }, "]c", function()
    move.goto_next_start("@class.outer", "textobjects")
  end, { silent = true })
  vim.keymap.set({ "n", "x", "o" }, "[f", function()
    move.goto_previous_start("@function.outer", "textobjects")
  end, { silent = true })
  vim.keymap.set({ "n", "x", "o" }, "[c", function()
    move.goto_previous_start("@class.outer", "textobjects")
  end, { silent = true })
end

local function setup_treesitter()
  local ok, treesitter = pcall(require, "nvim-treesitter")
  if not ok or type(treesitter.setup) ~= "function" then
    return
  end

  treesitter.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
  })

  local group = vim.api.nvim_create_augroup("devbox-treesitter", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      if ft == "" or should_disable(ft, args.buf) then
        return
      end

      pcall(vim.treesitter.start, args.buf)
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
  })

  setup_textobjects()
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  dependencies = {
    {
      "windwp/nvim-ts-autotag",
      opts = {},
    },
    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      branch = "main",
    },
    {
      "nvim-treesitter/nvim-treesitter-context",
      opts = {
        enable = true,
        mode = "topline",
        line_numbers = true,
      },
    },
  },
  config = setup_treesitter,
}
