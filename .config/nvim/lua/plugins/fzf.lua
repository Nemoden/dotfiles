return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- or if using mini.icons/mini.nvim
  -- dependencies = { "echasnovski/mini.icons" },
  opts = {},
  config = function()
    local fzf = require("fzf-lua")
    fzf.setup({
      {"ivy", "borderless"},
      winopts = { height=0.75, width=1 },
      keymap = {
        builtin = {
          ["<C-f>"] = "preview-page-down",
          ["<C-u>"] = "preview-page-up",
        }
      }
    })

    local key = vim.keymap
    key.set("n", "<C-p>", "<cmd>FzfLua files<cr>", { desc="Find files" })
    key.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc="[f]ind [f]ile" })
    key.set("n", "<leader>fw", "<cmd>FzfLua live_grep_native<cr>", { desc="[f]ind [w]ord" })
    key.set("n", "<leader>fr", "<cmd>FzfLua oldfiles<cr>", { desc="[f]ind [r]ecent" })
    key.set("n", "<leader>.", "<cmd>FzfLua buffers<cr>", { desc="Buffers" })
    key.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc="[f]ind [b]uffer" })
    key.set("n", "<leader>//", "<cmd>FzfLua resume<cr>", { desc="Resume fzf" })
    key.set("n", "gs", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", { desc="LSP Symbols" })
    key.set("n", "<leader>gs", "<cmd>FzfLua lsp_document_symbols<cr>", { desc="LSP Symbols" })
    key.set("n", "<leader>gr", "<cmd>FzfLua lsp_references<cr>", { desc = "LSP references" })
    key.set("n", "<leader>gi", "<cmd>FzfLua lsp_implementations<cr>", { desc = "LSP implementations" })
  end,
}
