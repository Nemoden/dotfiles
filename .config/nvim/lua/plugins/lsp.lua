-- https://github.com/nvim-telescope/telescope.nvim/issues/3328
return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "hrsh7th/nvim-cmp",
    "j-hui/fidget.nvim",
    "nvim-lua/plenary.nvim",
    "stevearc/conform.nvim",
    "williamboman/mason-lspconfig.nvim",
    "williamboman/mason.nvim",
    --"https://github.com/ray-x/lsp_signature.nvim",
  },

  config = function()
    require("conform").setup({
      formatters_by_ft = {
      }
    })
    local cmp = require('cmp')
    local cmp_lsp = require("cmp_nvim_lsp")
    local capabilities = vim.tbl_deep_extend(
      "force",
      {},
      vim.lsp.protocol.make_client_capabilities(),
      cmp_lsp.default_capabilities())

    local servers = {
      "gopls",
      "intelephense",
      "lua_ls",
      "pyright",
      "rust_analyzer",
    }

    require("fidget").setup({})
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = servers,
      handlers = {
        function(server_name) -- default handler (optional)
          require("lspconfig")[server_name].setup {
            capabilities = capabilities
          }
        end,

        zls = function()
          local lspconfig = require("lspconfig")
          lspconfig.zls.setup({
            root_dir = lspconfig.util.root_pattern(".git", "build.zig", "zls.json"),
            settings = {
              zls = {
                enable_inlay_hints = true,
                enable_snippets = true,
                warn_style = true,
              },
            },
          })
          vim.g.zig_fmt_parse_errors = 0
          vim.g.zig_fmt_autosave = 0

        end,
        ["lua_ls"] = function()
          local lspconfig = require("lspconfig")
          lspconfig.lua_ls.setup {
            capabilities = capabilities,
            settings = {
              Lua = {
                runtime = { version = "Lua 5.1" },
                diagnostics = {
                  globals = { "bit", "vim", "it", "describe", "before_each", "after_each" },
                }
              }
            }
          }
        end,

        ["intelephense"] = function()
          local lspconfig = require("lspconfig")
          local home = vim.fn.expand("$HOME")
          lspconfig.intelephense.setup{
            capabilities = capabilities,
            init_options = {
              licenceKey = home .. "/.secrets/intelephense.txt"
            },
            settings = {
              intelephense = {
                environment = {
                },
              },
            }
          }
        end,
      }
    })

    local cmp_select = { behavior = cmp.SelectBehavior.Select }

    cmp.setup({
      mapping = cmp.mapping.preset.insert({
        ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
        ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
        ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
        ['<Enter>'] = cmp.mapping.confirm({ select = true }),
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<Tab>"] = cmp.mapping(function (fallback)
          if cmp.visible() then
            cmp.select_next_item()
          else
            fallback()
          end
        end, {'i', 's'}),
        ["<S-Tab>"] = cmp.mapping(function (fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          else
            fallback()
          end
        end, {'i', 's'})
      }),
      sources = cmp.config.sources({
        { name = 'nvim_lsp' }, { name = 'buffer' }
      }),
    })

    --require('lsp_signature').setup({ })

    vim.diagnostic.config({
      -- update_in_insert = true,
      float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })
    vim.api.nvim_set_keymap(
      'n',
      '<leader>gd',
      '<cmd>lua vim.lsp.buf.definition()<CR>',
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      'n',
      '<leader>rn',
      '<cmd>lua vim.lsp.buf.rename()<CR>',
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      'n',
      '<leader>gi',
      '<cmd>lua vim.lsp.buf.implementation()<CR>',
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      'i',
      '<C-k>',
      '<cmd>lua vim.lsp.buf.signature_help()<CR>',
      { noremap = true, silent = true }
    )
    vim.api.nvim_set_keymap(
      'n',
      'K',
      '<cmd>lua vim.lsp.buf.hover()<CR>',
      { noremap = true, silent = true }
    )
  end
}
