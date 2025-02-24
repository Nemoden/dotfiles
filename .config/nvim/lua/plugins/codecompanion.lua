-- https://github.com/jcorbin/home/blob/f0f2b2123c382d800f672f1d3316b878a172e8c1/.config/nvim/lua/plugins/ai.lua#L91
-- https://github.com/zmre/pwnvim/blob/55d77729fecc8590167ef2b57976760245e2edfd/pwnvim/plugins.lua#L893

vim.cmd([[cab cc CodeCompanion]])
vim.cmd([[cab /b /buffer]])

return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    { "<leader>cc", function() require('codecompanion').toggle() end, desc = "Toggle AI chat" },
    { "<leader>ce", mode = "v", function() require("codecompanion").prompt("explain") end },
  },
  config = function()
    local home = vim.fn.expand("$HOME")
    local api_key_file = home .. "/.gogpt"
    local api_key = vim.fn.filereadable(api_key_file) == 1 and "cmd:cat " .. api_key_file or nil

    if not api_key then
      print("Error: OpenAI API key file not found at " .. api_key_file)
      return
    end

    require("codecompanion").setup({
      adapters = {
        openai = function()
          return require("codecompanion.adapters").extend("openai", {
            env = { api_key = api_key },
            model = "o3-mini-high",
          })
        end,
      },
      strategies = {
        chat = {
          adapter = "openai",
          slash_commands = {
            ['buffer'] = {
              opts = {
                provider = 'fzf_lua',
              },
            },
            ['file'] = {
              opts = {
                provider = 'fzf_lua',
              },
            },
            ['help'] = {
              opts = {
                provider = 'fzf_lua',
              },
            },
          },
        },
        inline = { adapter = "openai" },
      },
    })

    -- Add buffer local mappings for codecompanion
    vim.api.nvim_create_augroup('CodeCompanion', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = 'CodeCompanion',
      pattern = 'codecompanion',
      callback = function()
        local bufnr = vim.api.nvim_get_current_buf()
        -- Insert mode: Map <C-c> to <Esc>
        vim.api.nvim_buf_set_keymap(bufnr, 'i', '<C-c>', '<Esc>', { noremap = true, silent = true })
        -- Normal mode: Map <C-c> to toggle chat
        vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-c>', ":lua require('codecompanion').toggle()<CR>", { noremap = true, silent = true })
      end,
    })
  end,
}
