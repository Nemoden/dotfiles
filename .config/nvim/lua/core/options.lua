vim.g.netrw_liststyle = 3

local opt = vim.opt -- for conciseness

opt.fixeol = false

-- line numbers
opt.relativenumber = true -- show relative line numbers
opt.number = true -- shows absolute line number on cursor line (when relative number is on)

-- tabs & indentation
opt.tabstop = 2 -- 2 spaces for tabs (prettier default)
opt.shiftwidth = 2 -- 2 spaces for indent width
opt.expandtab = true -- expand tab to spaces
opt.autoindent = true -- copy indent from current line when starting new one

-- scrolloff
opt.scrolloff = 9

-- line wrapping
opt.wrap = false -- disable line wrapping

-- search settings
opt.ignorecase = true -- ignore case when searching
opt.smartcase = true -- if you include mixed case in your search, assumes you want case-sensitive

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- cursor line
opt.cursorline = true -- highlight the current cursor line

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function() vim.highlight.on_yank() end,
})

-- appearance

-- turn on termguicolors for nightfly colorscheme to work
-- (have to use iterm2 or any other true color terminal)
opt.termguicolors = true
opt.background = "dark" -- colorschemes that can be light or dark will be made dark
opt.signcolumn = "yes" -- show sign column so that text doesn't shift

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 300

-- backspace
opt.backspace = "indent,eol,start" -- allow backspace on indent, end of line or insert mode start position

-- clipboard
opt.clipboard:append("unnamedplus") -- use system clipboard as default register

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
--vim.schedule(function()
--  vim.opt.clipboard = 'unnamedplus'
--end)

-- Save undo history
vim.opt.undofile = true

-- split windows
opt.splitright = true -- split vertical window to the right
opt.splitbelow = true -- split horizontal window to the bottom

-- turn off swapfile
opt.swapfile = false

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Copy file name
vim.keymap.set('n', ',cf', function()
  vim.fn.setreg('+', vim.fn.expand("%:."))
  vim.notify_once("file name copied to the clipboard!", vim.log.levels.INFO)
end, { silent = true })

-- Copy file path
vim.keymap.set('n', ',cp', function()
  vim.fn.setreg('+', vim.fn.expand("%:p"))
  vim.notify_once("file path copied to the clipboard!", vim.log.levels.INFO)
end, { silent = true })

-- Open file in GitHub with line number and branch
vim.keymap.set('n', '<Leader>gh', function()
  local file = vim.fn.shellescape(vim.fn.expand("%:."))
  local line = vim.fn.line(".")
  local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
  vim.cmd('!gh browse ' .. file .. ':' .. line .. ' --branch ' .. branch)
end, { silent = true })

vim.api.nvim_create_autocmd('BufReadPost', {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 1 and mark[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "php",
  callback = function()
    vim.wo.colorcolumn = "121"
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.formatoptions = "croqj"
    vim.bo.textwidth = 74
    vim.bo.comments = ":#\\:,:#"
    vim.g.python_highlight_all = 1
    vim.g.python_highlight_exceptions = 0
    vim.g.python_highlight_builtins = 0
    vim.g.python_slow_sync = 1
  end
})

local function set_expandtab_options_2()
  vim.bo.expandtab = true
  vim.bo.shiftwidth = 2
  vim.bo.tabstop = 2
end

local function set_expandtab_options_4()
  vim.bo.expandtab = true
  vim.bo.shiftwidth = 4
  vim.bo.tabstop = 4
end

for _, ft in ipairs({"php"}) do
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = set_expandtab_options_4
  })
end

for _, ft in ipairs({"cucumber", "yaml", "helm", "json", "ruby", "css", "javascript", "vue", "proto", "scheme", "lisp"}) do
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = set_expandtab_options_2
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.wo.list = false
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "make",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    vim.api.nvim_buf_set_keymap(0, "n", "<leader>cb", ":!cargo build<CR>", { noremap = true, silent = false })
    vim.api.nvim_buf_set_keymap(0, "n", "<leader>cr", ":!cargo run<CR>", { noremap = true, silent = false })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = 0,
      callback = function()
        local ft = vim.bo.filetype
        if ft == "netrw" then
          vim.cmd("bd")
        end
      end
    })
  end
})
