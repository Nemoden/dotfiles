-- set leader key to space
vim.g.mapleader = ","
vim.g.maplocalleader = " "

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------

-- use jk to exit insert mode
-- keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
-- keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<localleader>=", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<localleader>-", "<C-x>", { desc = "Decrement number" }) -- decrement
keymap.set("n", "<leader><leader>", "<C-^>", { desc = "Back to previous" }) -- decrement

keymap.set("n", "<Tab>", ":bnext<cr>", { desc = "Next buffer" })
keymap.set("n", "<S-Tab>", ":bprevious<cr>", { desc = "Previous buffer" })

keymap.set("v", "<leader>s", ":%sort<cr>", { desc = "Sort ASC", silent = true })
keymap.set("v", "<leader>S", ":%sort!<cr>", { desc = "Sort DESC", silent = true })

keymap.set("n", "<leader>df", function() vim.diagnostic.open_float({ focusable = true }) end, { desc="Open diagnostic message in floating window" })

-- window management
-- keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
-- keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
-- keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
-- keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

-- keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
-- keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
-- keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
-- keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
-- keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<localleader>R", [[:term PYTHONPATH=$(git rev-parse --show-toplevel) python3 %<CR>]], { buffer = true })
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<localleader>r", function()
      vim.cmd("vsplit | terminal PYTHONPATH=$(git rev-parse --show-toplevel) python3 " .. vim.fn.expand("%"))
    end, { buffer = true })
  end
})

vim.api.nvim_create_user_command("PrettyJson", function(opts)
  require("pretty_json").pretty_print_json_range(opts.line1, opts.line2)
end, {
  range = true,  -- 💡 this allows :'<,'> to pass line1 and line2
})
vim.keymap.set("v", "<localleader>pj", [[:'<,'>PrettyJson<CR>]], { desc = "Pretty-print JSON", silent = true })


--  vim.keymap.set("v", "<localleader>ppj", function()
--    require("pretty_json").pretty_print_json_range()
--  end, { desc = "Pretty print selected JSON" })

---------------------
-- Whitespace Utilities -------------------

-- Highlight group for trailing whitespace
vim.api.nvim_set_hl(0, "TrailingWhitespace", { bg = "#ff5555" })

-- Track whether trailing whitespace highlighting is enabled
local trailing_ws_visible = false
local trailing_ws_match_id = nil

-- Toggle trailing whitespace visibility
local function toggle_trailing_whitespace()
  if trailing_ws_visible then
    if trailing_ws_match_id then
      pcall(vim.fn.matchdelete, trailing_ws_match_id)
      trailing_ws_match_id = nil
    end
    trailing_ws_visible = false
    vim.notify("Trailing whitespace: hidden", vim.log.levels.INFO)
  else
    trailing_ws_match_id = vim.fn.matchadd("TrailingWhitespace", [[\s\+$]])
    trailing_ws_visible = true
    vim.notify("Trailing whitespace: visible", vim.log.levels.INFO)
  end
end

-- Remove trailing whitespace from the entire file
local function strip_trailing_whitespace()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd([[%s/\s\+$//e]])
  vim.api.nvim_win_set_cursor(0, cursor_pos)
  vim.notify("Trailing whitespace removed", vim.log.levels.INFO)
end

-- Toggle listchars visibility (tabs, spaces, etc.)
local function toggle_listchars()
  vim.wo.list = not vim.wo.list
  vim.notify("Listchars: " .. (vim.wo.list and "visible" or "hidden"), vim.log.levels.INFO)
end

-- Convert tabs to spaces in the entire file
local function tabs_to_spaces()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd("retab")
  vim.api.nvim_win_set_cursor(0, cursor_pos)
  vim.notify("Tabs converted to spaces", vim.log.levels.INFO)
end

-- Convert spaces to tabs in the entire file
local function spaces_to_tabs()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local spaces = string.rep(" ", vim.bo.tabstop)
  vim.cmd([[%s/]] .. spaces .. [[\ze\S/\t/ge]])
  vim.api.nvim_win_set_cursor(0, cursor_pos)
  vim.notify("Leading spaces converted to tabs", vim.log.levels.INFO)
end

keymap.set("n", "<leader>wt", toggle_trailing_whitespace, { desc = "Toggle trailing whitespace visibility" })
keymap.set("n", "<leader>wd", strip_trailing_whitespace, { desc = "Delete trailing whitespace" })
keymap.set("n", "<leader>wl", toggle_listchars, { desc = "Toggle listchars (tabs/spaces)" })
keymap.set("n", "<leader>ws", tabs_to_spaces, { desc = "Convert tabs to spaces" })
keymap.set("n", "<leader>wT", spaces_to_tabs, { desc = "Convert spaces to tabs" })
