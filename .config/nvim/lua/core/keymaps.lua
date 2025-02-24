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
keymap.set("n", "<localleader>+", "<C-a>", { desc = "Increment number" }) -- increment
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
