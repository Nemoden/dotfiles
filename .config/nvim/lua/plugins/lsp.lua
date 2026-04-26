return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "j-hui/fidget.nvim",
    "nvim-lua/plenary.nvim",
    "saghen/blink.cmp",
    "stevearc/conform.nvim",
    { "mason-org/mason.nvim",            opts = {} },
    { "mason-org/mason-lspconfig.nvim",  opts = {} },
  },

  config = function()
    -- Formatters
    require("conform").setup({
      formatters_by_ft = {
        javascript      = { "prettier" },
        typescript      = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        json            = { "prettier" },
        jsonc           = { "prettier" },
        css             = { "prettier" },
        scss            = { "prettier" },
        html            = { "prettier" },
      },
      format_on_save = false,
    })

    require("fidget").setup({})

    -- Per-server configuration via the new vim.lsp.config() API (Neovim 0.11+).
    -- mason-lspconfig will call vim.lsp.enable() for each installed server automatically.
    -- blink.cmp injects its capabilities globally; no need to pass them here.

    vim.lsp.config("lua_ls", {
      settings = {
        Lua = {
          runtime = { version = "Lua 5.1" },
          diagnostics = {
            globals = { "bit", "vim", "it", "describe", "before_each", "after_each" },
          },
        },
      },
    })

    vim.lsp.config("intelephense", {
      init_options = {
        licenceKey = vim.fn.expand("$HOME") .. "/.secrets/intelephense.txt",
      },
      settings = {
        intelephense = {
          environment = {},
        },
      },
    })

    vim.lsp.config("zls", {
      root_markers = { ".git", "build.zig", "zls.json" },
      settings = {
        zls = {
          enable_inlay_hints = true,
          enable_snippets    = true,
          warn_style         = true,
        },
      },
    })
    vim.g.zig_fmt_parse_errors = 0
    vim.g.zig_fmt_autosave = 0

    vim.lsp.config("ts_ls", {
      settings = {
        typescript = {
          inlayHints = {
            includeInlayParameterNameHints        = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints          = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints  = true,
            includeInlayEnumMemberValueHints        = true,
          },
        },
        javascript = {
          inlayHints = {
            includeInlayParameterNameHints        = "all",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = true,
            includeInlayVariableTypeHints          = false,
            includeInlayPropertyDeclarationTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints  = true,
            includeInlayEnumMemberValueHints        = true,
          },
        },
      },
    })

    vim.lsp.config("eslint", {
      settings = {
        workingDirectories = { mode = "auto" },
      },
      on_attach = function(_, bufnr)
        -- Auto-fix on save
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          command = "EslintFixAll",
        })
      end,
    })

    -- Let rust_analyzer use the binary from PATH (e.g. nix/direnv shell)
    -- instead of mason's standalone binary which may mismatch the toolchain.
    vim.lsp.config("rust_analyzer", {
      cmd = { "rust-analyzer" },
    })
    vim.lsp.enable("rust_analyzer")

    -- Ensure these servers are installed by mason
    require("mason-lspconfig").setup({
      ensure_installed = {
        "eslint",
        "gopls",
        "intelephense",
        "lua_ls",
        "pyright",
        "ts_ls",
      },
      automatic_enable = true,
    })

    -- Diagnostics display
    vim.diagnostic.config({
      float = {
        focusable = false,
        style     = "minimal",
        border    = "rounded",
        source    = "always",
        header    = "",
        prefix    = "",
      },
    })

    -- Toggle diagnostics
    local function toggle_diagnostics()
      local current = vim.diagnostic.config().virtual_text
      vim.diagnostic.config({
        virtual_text = not current,
        signs        = not current,
        underline    = not current,
      })
    end
    vim.keymap.set("n", "<localleader>d", toggle_diagnostics, { noremap = true, silent = true })

    -- LSP keymaps
    vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition,    { noremap = true, silent = true })
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,        { noremap = true, silent = true })
    vim.keymap.set("i", "<C-k>",      vim.lsp.buf.signature_help, { noremap = true, silent = true })
    vim.keymap.set("n", "K",          vim.lsp.buf.hover,          { noremap = true, silent = true })
  end,
}
